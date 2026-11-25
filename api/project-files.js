const { authenticateRequest, getSupabaseUrl } = require('./_lib/auth');
const {
  hasPermission,
  WorkspaceAccessError,
  withWorkspaceTransaction,
} = require('./_lib/database');
const { getWorkspaceId } = require('./_lib/workspace_context');
const { attachRequestId } = require('./_lib/request_id');
const {
  enforceUserRateLimit,
  respondToRateLimit,
} = require('./_lib/rate_limit');

const maximumRequestBytes = 8192;
const allowedMimeTypes = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'application/pdf',
  'text/plain',
  'text/csv',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
]);
const safeSegmentPattern = /^[A-Za-z0-9._-]{1,160}$/;
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

class HttpError extends Error {
  constructor(statusCode, code) {
    super(code);
    this.name = 'HttpError';
    this.statusCode = statusCode;
    this.code = code;
  }
}

function isRecord(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function requireProjectPermission(access, projectId, permission) {
  const projectPermissions = access.projectPermissions.get(projectId) || [];
  if (!hasPermission(access, permission) &&
      !projectPermissions.includes(permission) &&
      !projectPermissions.includes('projects.manage')) {
    throw new WorkspaceAccessError(403, 'permission_denied');
  }
}

function getServiceKey(env) {
  const key = env.SUPABASE_SERVICE_ROLE_KEY;
  if (typeof key !== 'string' || key.trim().length === 0) {
    throw new HttpError(503, 'project_file_service_not_configured');
  }
  return key;
}

function getSafePathSegments(path) {
  if (typeof path !== 'string' || path.includes('..')) {
    throw new HttpError(400, 'invalid_project_file_path');
  }
  const segments = path.split('/');
  if (segments.length !== 3 ||
      segments.some((segment) => !safeSegmentPattern.test(segment))) {
    throw new HttpError(400, 'invalid_project_file_path');
  }
  return segments;
}

function storageObjectUrl(supabaseUrl, endpoint, path = '') {
  const encodedPath = path
    ? path.split('/').map(encodeURIComponent).join('/')
    : '';
  return new URL(
    `/storage/v1/object/${endpoint ? `${endpoint}/` : ''}project-files${encodedPath
      ? `/${encodedPath}`
      : ''}`,
    supabaseUrl,
  );
}

async function providerRequest(url, method, serviceKey, body, providerFetch) {
  let response;
  try {
    response = await providerFetch(url, {
      method,
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        ...(body == null ? {} : { 'Content-Type': 'application/json' }),
      },
      ...(body == null ? {} : { body: JSON.stringify(body) }),
      signal: AbortSignal.timeout(10000),
    });
  } catch {
    throw new HttpError(502, 'project_file_provider_unavailable');
  }
  if (!response.ok) {
    throw new HttpError(502, 'project_file_provider_failed');
  }
  return response;
}

async function createUploadUrl(path, env, providerFetch = fetch) {
  const serviceKey = getServiceKey(env);
  const supabaseUrl = getSupabaseUrl(env);
  const response = await providerRequest(
    storageObjectUrl(supabaseUrl, 'upload/sign', path),
    'POST',
    serviceKey,
    { upsert: false },
    providerFetch,
  );
  let result;
  try {
    result = await response.json();
  } catch {
    throw new HttpError(502, 'project_file_provider_failed');
  }
  if (typeof result.token !== 'string' || result.token.length === 0) {
    throw new HttpError(502, 'project_file_provider_failed');
  }
  const uploadUrl = storageObjectUrl(supabaseUrl, 'upload/sign', path);
  uploadUrl.searchParams.set('token', result.token);
  return uploadUrl.toString();
}

async function createDownloadUrl(path, env, providerFetch = fetch) {
  getSafePathSegments(path);
  const serviceKey = getServiceKey(env);
  const supabaseUrl = getSupabaseUrl(env);
  const response = await providerRequest(
    storageObjectUrl(supabaseUrl, 'sign', path),
    'POST',
    serviceKey,
    { expiresIn: 60 },
    providerFetch,
  );
  let result;
  try {
    result = await response.json();
  } catch {
    throw new HttpError(502, 'project_file_provider_failed');
  }
  if (typeof result.signedURL !== 'string' || result.signedURL.length === 0) {
    throw new HttpError(502, 'project_file_provider_failed');
  }
  const signedUrl = result.signedURL.startsWith('/storage/v1/')
    ? new URL(result.signedURL, supabaseUrl)
    : result.signedURL.startsWith('/object/')
      ? new URL(`/storage/v1${result.signedURL}`, supabaseUrl)
      : new URL(result.signedURL, supabaseUrl);
  if (signedUrl.origin !== new URL(supabaseUrl).origin) {
    throw new HttpError(502, 'project_file_provider_failed');
  }
  return signedUrl.toString();
}

async function deleteStorageObjects(paths, env, providerFetch = fetch) {
  const serviceKey = getServiceKey(env);
  const supabaseUrl = getSupabaseUrl(env);
  await providerRequest(
    storageObjectUrl(supabaseUrl, ''),
    'DELETE',
    serviceKey,
    { prefixes: paths },
    providerFetch,
  );
}

function createProjectFilesHandler({
  authenticate = authenticateRequest,
  withWorkspace = withWorkspaceTransaction,
  rateLimit = enforceUserRateLimit,
  providerFetch = fetch,
  env = process.env,
  logger = console.error,
} = {}) {
  return async function projectFilesHandler(req, res) {
    const requestId = attachRequestId(res);
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Vary', 'Authorization');
    if (!['POST', 'DELETE'].includes(req.method)) {
      res.setHeader('Allow', 'POST, DELETE');
      return res.status(405).json({ error: 'method_not_allowed' });
    }

    try {
      const { userId } = await authenticate(req);
      if (rateLimit) {
        await rateLimit(userId, 'project_files', {
          limit: 120,
          windowSeconds: 60,
        });
      }
      if (!isRecord(req.body) ||
          Buffer.byteLength(JSON.stringify(req.body)) > maximumRequestBytes) {
        throw new HttpError(400, 'invalid_project_file_request');
      }
      const workspaceId = getWorkspaceId(req);

      if (req.method === 'DELETE') {
        const paths = req.body.paths;
        if (!Array.isArray(paths) || paths.length < 1 || paths.length > 100) {
          throw new HttpError(400, 'invalid_project_file_request');
        }
        const normalizedPaths = paths.map((path) => {
          const segments = getSafePathSegments(path);
          if (segments[0] !== workspaceId && !uuidPattern.test(segments[0])) {
            throw new HttpError(400, 'invalid_project_file_path');
          }
          return { path, projectId: segments[1] };
        });
        await withWorkspace(
          userId,
          workspaceId,
          async (client, access) => {
            const workspace = await client.query(
              'SELECT owner_user_id FROM workspaces WHERE id = $1',
              [workspaceId],
            );
            const ownerUserId = workspace.rows[0]?.owner_user_id;
            for (const { projectId } of normalizedPaths) {
              requireProjectPermission(access, projectId, 'manageFiles');
            }
            if (normalizedPaths.some(({ path }) => {
              const [prefix] = path.split('/');
              return prefix !== workspaceId && prefix !== ownerUserId;
            })) {
              throw new HttpError(400, 'invalid_project_file_path');
            }
          },
        );
        await deleteStorageObjects(
          normalizedPaths.map(({ path }) => path),
          env,
          providerFetch,
        );
        return res.status(200).json({ deleted: paths.length });
      }

      const action = req.body.action;
      const projectId = req.body.projectId;
      const assetId = req.body.assetId;
      if (!['create_upload', 'create_download'].includes(action) ||
          typeof projectId !== 'string' ||
          !safeSegmentPattern.test(projectId) ||
          typeof assetId !== 'string' ||
          !safeSegmentPattern.test(assetId)) {
        throw new HttpError(400, 'invalid_project_file_request');
      }
      const data = await withWorkspace(
        userId,
        workspaceId,
        async (client, access) => {
          const permission = action === 'create_upload'
            ? 'manageFiles'
            : 'viewFiles';
          requireProjectPermission(access, projectId, permission);
          const project = await client.query(
            `SELECT id FROM studio_projects
             WHERE workspace_id = $1 AND id = $2`,
            [workspaceId, projectId],
          );
          if (project.rowCount !== 1) {
            throw new HttpError(404, 'project_not_found');
          }
          if (action === 'create_upload') {
            if (!allowedMimeTypes.has(req.body.mimeType)) {
              throw new HttpError(400, 'invalid_project_file_type');
            }
            return {
              storagePath: `${workspaceId}/${projectId}/${assetId}`,
            };
          }
          const asset = await client.query(
            `SELECT storage_path AS "storagePath"
             FROM project_assets
             WHERE workspace_id = $1 AND project_id = $2 AND id = $3`,
            [workspaceId, projectId, assetId],
          );
          if (asset.rowCount !== 1) {
            throw new HttpError(404, 'project_file_not_found');
          }
          return { storagePath: asset.rows[0].storagePath };
        },
      );
      if (action === 'create_upload') {
        data.uploadUrl = await createUploadUrl(
          data.storagePath,
          env,
          providerFetch,
        );
      } else {
        data.downloadUrl = await createDownloadUrl(
          data.storagePath,
          env,
          providerFetch,
        );
      }
      return res.status(200).json(data);
    } catch (error) {
      if (respondToRateLimit(error, res)) return;
      if (error instanceof HttpError ||
          error instanceof WorkspaceAccessError ||
          (Number.isInteger(error?.statusCode) && error.statusCode === 401)) {
        return res.status(error.statusCode).json({
          error: error instanceof HttpError ||
              error instanceof WorkspaceAccessError
            ? error.code
            : 'unauthorized',
        });
      }
      logger('Project file request failed.', {
        requestId,
        errorName: error instanceof Error ? error.name : 'UnknownError',
        ...(typeof error?.code === 'string' ? { errorCode: error.code } : {}),
      });
      return res.status(500).json({ error: 'internal_server_error' });
    }
  };
}

const handler = createProjectFilesHandler();
Object.assign(handler, {
  createProjectFilesHandler,
  createDownloadUrl,
  createUploadUrl,
  getSafePathSegments,
});
module.exports = handler;
