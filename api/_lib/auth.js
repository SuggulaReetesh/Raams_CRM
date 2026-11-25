const jwksByUrl = new Map();
const userIdPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

class AuthenticationError extends Error {
  constructor(message = 'A valid bearer token is required.') {
    super(message);
    this.name = 'AuthenticationError';
    this.statusCode = 401;
  }
}

function getSupabaseUrl(env = process.env) {
  const configured = env.SUPABASE_URL?.trim();
  if (!configured) {
    throw new Error('SUPABASE_URL is not configured.');
  }

  let url;
  try {
    url = new URL(configured);
  } catch {
    throw new Error('SUPABASE_URL must be a valid HTTPS URL.');
  }

  if (
    !['https:', ...(env.APP_ENV === 'development' ? ['http:'] : [])].includes(
      url.protocol,
    ) ||
    !url.hostname ||
    url.username ||
    url.password ||
    url.search ||
    url.hash ||
    url.pathname !== '/'
  ) {
    throw new Error('SUPABASE_URL must be an origin using HTTPS.');
  }

  return url.origin;
}

async function authenticateRequest(req, env = process.env) {
  const authorization = req.headers?.authorization;
  const match =
    typeof authorization === 'string' &&
    /^Bearer ([^\s]+)$/i.exec(authorization);
  if (!match) throw new AuthenticationError();

  const supabaseUrl = getSupabaseUrl(env);
  const { createRemoteJWKSet, jwtVerify } = await import('jose');
  let jwks = jwksByUrl.get(supabaseUrl);
  if (!jwks) {
    jwks = createRemoteJWKSet(
      new URL('/auth/v1/.well-known/jwks.json', supabaseUrl),
    );
    jwksByUrl.set(supabaseUrl, jwks);
  }

  let payload;
  try {
    ({ payload } = await jwtVerify(match[1], jwks, {
      issuer: `${supabaseUrl}/auth/v1`,
      audience: 'authenticated',
      algorithms: ['ES256', 'RS256'],
    }));
  } catch {
    throw new AuthenticationError('The bearer token is invalid or expired.');
  }

  if (typeof payload.sub !== 'string' || !userIdPattern.test(payload.sub)) {
    throw new AuthenticationError('The bearer token has no valid user ID.');
  }
  const metadata = payload.user_metadata;
  const metadataName =
    metadata && typeof metadata === 'object'
      ? metadata.full_name || metadata.name
      : undefined;
  const email = typeof payload.email === 'string' ? payload.email : null;
  const displayName =
    typeof metadataName === 'string' && metadataName.trim().length > 0
      ? metadataName.trim().slice(0, 120)
      : email?.split('@')[0]?.slice(0, 120) || 'Studio owner';
  return {
    userId: payload.sub,
    email,
    emailVerified: payload.email_verified === true,
    profile: { displayName, email },
  };
}

module.exports = {
  AuthenticationError,
  authenticateRequest,
  getSupabaseUrl,
};
