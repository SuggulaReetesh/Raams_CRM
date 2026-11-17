const { authenticateRequest } = require('./_lib/auth');
const { withUserTransaction } = require('./_lib/database');
const {
  enforceUserRateLimit,
  respondToRateLimit,
} = require('./_lib/rate_limit');
const { attachRequestId } = require('./_lib/request_id');
const {
  encryptSecrets,
} = require('./_lib/integration_secrets');

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

function validateIntegration(provider, settings) {
  if (!isRecord(settings)) throw new HttpError(400, 'invalid_integration');
  if (provider === 'postal') {
    const { smtpUser, smtpPassword, fromAddress, fromName } = settings;
    if (typeof smtpUser !== 'string' ||
        smtpUser.trim().length === 0 ||
        smtpUser.length > 200 ||
    /[\r\n]/.test(smtpUser) ||
        typeof smtpPassword !== 'string' ||
        smtpPassword.length === 0 ||
        smtpPassword.length > 1000 ||
        typeof fromAddress !== 'string' ||
        !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(fromAddress) ||
        fromAddress.length > 254 ||
        typeof fromName !== 'string' ||
        fromName.trim().length === 0 ||
        fromName.length > 120 ||
        /[\r\n]/.test(fromName)) {
      throw new HttpError(400, 'invalid_postal_settings');
    }
    return {
      accountId: null,
      accountHint: fromAddress,
      secrets: {
        smtpUser: smtpUser.trim(),
        smtpPassword,
        fromAddress: fromAddress.trim(),
        fromName: fromName.trim(),
      },
    };
  }
  if (provider === 'whatsapp') {
    const { phoneNumberId, accessToken } = settings;
    if (typeof phoneNumberId !== 'string' ||
        !/^\d{6,32}$/.test(phoneNumberId) ||
        typeof accessToken !== 'string' ||
        accessToken.trim().length < 20 ||
        accessToken.length > 4096 ||
        /[\r\n]/.test(accessToken)) {
      throw new HttpError(400, 'invalid_whatsapp_settings');
    }
    return {
      accountId: phoneNumberId,
      accountHint: `WhatsApp ••••${phoneNumberId.slice(-4)}`,
      secrets: {
        phoneNumberId,
        accessToken: accessToken.trim(),
      },
    };
  }
  throw new HttpError(400, 'invalid_integration_provider');
}

function createIntegrationsHandler({
  authenticate = authenticateRequest,
  withTransaction = withUserTransaction,
  rateLimit = null,
  env = process.env,
  logger = console.error,
} = {}) {
  return async function integrationsHandler(req, res) {
    const requestId = attachRequestId(res);
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Vary', 'Authorization');
    if (!['GET', 'PUT', 'DELETE'].includes(req.method)) {
      res.setHeader('Allow', 'GET, PUT, DELETE');
      return res.status(405).json({ error: 'method_not_allowed' });
    }

    try {
      const { userId } = await authenticate(req);
      if (rateLimit) {
        await rateLimit(
          userId,
          req.method === 'GET' ? 'integrations_read' : 'integrations_write',
          {
            limit: req.method === 'GET' ? 60 : 20,
            windowSeconds: 60,
          },
        );
      }
      if (req.method === 'GET') {
        const integrations = await withTransaction(userId, async (client) => {
          const result = await client.query(
            `SELECT provider, account_hint, updated_at
             FROM workspace_integrations
             WHERE workspace_id IN (
               SELECT id FROM workspaces WHERE owner_user_id = $1
             )`,
            [userId],
          );
          return result.rows;
        });
        return res.status(200).json({
          integrations: integrations.map((integration) => ({
            provider: integration.provider,
            configured: true,
            accountHint: integration.account_hint,
            updatedAt: integration.updated_at,
          })),
        });
      }

      if (!isRecord(req.body) ||
          Buffer.byteLength(JSON.stringify(req.body)) > 8192) {
        throw new HttpError(400, 'invalid_integration');
      }
      const provider = req.body.provider;
      if (typeof provider !== 'string' ||
          !['postal', 'whatsapp'].includes(provider)) {
        throw new HttpError(400, 'invalid_integration_provider');
      }

      if (req.method === 'DELETE') {
        await withTransaction(userId, async (client) => {
          await client.query(
            `DELETE FROM workspace_integrations
             WHERE provider = $1
               AND workspace_id IN (
                 SELECT id FROM workspaces WHERE owner_user_id = $2
               )`,
            [provider, userId],
          );
        });
        return res.status(200).json({ provider, configured: false });
      }

      const workspaceName = req.body.workspaceName;
      if (workspaceName !== undefined &&
          (typeof workspaceName !== 'string' ||
            workspaceName.trim().length === 0 ||
            workspaceName.length > 80)) {
        throw new HttpError(400, 'invalid_workspace_name');
      }
      const validated = validateIntegration(provider, req.body.settings);
      const encrypted = encryptSecrets(
        validated.secrets,
        `${userId}:${provider}`,
        env,
      );
      await withTransaction(userId, async (client) => {
        await client.query(
          `INSERT INTO workspaces (owner_user_id, name)
           VALUES ($1, $2)
           ON CONFLICT (owner_user_id) DO NOTHING`,
          [userId, workspaceName?.trim() || 'Studio'],
        );
        const workspace = await client.query(
          'SELECT id FROM workspaces WHERE owner_user_id = $1',
          [userId],
        );
        await client.query(
          `INSERT INTO workspace_integrations
             (workspace_id, owner_user_id, provider, account_id, account_hint,
              secret_ciphertext, secret_iv, secret_auth_tag, updated_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, now())
           ON CONFLICT (workspace_id, provider) DO UPDATE SET
             account_id = EXCLUDED.account_id,
             account_hint = EXCLUDED.account_hint,
             secret_ciphertext = EXCLUDED.secret_ciphertext,
             secret_iv = EXCLUDED.secret_iv,
             secret_auth_tag = EXCLUDED.secret_auth_tag,
             updated_at = now()`,
          [
            workspace.rows[0].id,
            userId,
            provider,
            validated.accountId,
            validated.accountHint,
            encrypted.ciphertext,
            encrypted.iv,
            encrypted.authTag,
          ],
        );
      });
      return res.status(200).json({
        provider,
        configured: true,
        accountHint: validated.accountHint,
      });
    } catch (error) {
      if (respondToRateLimit(error, res)) return;
      if (error instanceof HttpError ||
          (Number.isInteger(error?.statusCode) && error.statusCode === 401)) {
        return res.status(error.statusCode).json({
          error: error instanceof HttpError ? error.code : 'unauthorized',
        });
      }
      logger('Integration settings request failed.', {
        requestId,
        errorName: error instanceof Error ? error.name : 'UnknownError',
        ...(typeof error?.code === 'string' ? { errorCode: error.code } : {}),
      });
      return res.status(500).json({ error: 'internal_server_error' });
    }
  };
}

const handler = createIntegrationsHandler({
  rateLimit: enforceUserRateLimit,
});
Object.assign(handler, { createIntegrationsHandler, validateIntegration });

module.exports = handler;
