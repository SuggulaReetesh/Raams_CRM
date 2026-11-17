const runtimeEnvironments = new Set([
  'development',
  'staging',
  'production',
]);

function getRuntimeEnvironment(env = process.env) {
  const configured = env.APP_ENV || env.VERCEL_ENV || 'development';
  const environment = configured === 'preview' ? 'staging' : configured;
  if (!runtimeEnvironments.has(environment)) {
    throw new Error(`Unsupported APP_ENV "${configured}".`);
  }
  return environment;
}

function getDatabaseUrl(env = process.env) {
  const databaseUrl = env.DATABASE_URL?.trim();
  if (!databaseUrl) {
    throw new Error('DATABASE_URL is not configured.');
  }

  let parsedUrl;
  try {
    parsedUrl = new URL(databaseUrl);
  } catch {
    throw new Error('DATABASE_URL must be a valid PostgreSQL URL.');
  }

  if (
    !['postgres:', 'postgresql:'].includes(parsedUrl.protocol) ||
    !parsedUrl.hostname ||
    !parsedUrl.username
  ) {
    throw new Error('DATABASE_URL must be a valid PostgreSQL connection URL.');
  }

  return databaseUrl;
}

module.exports = { getDatabaseUrl, getRuntimeEnvironment };
