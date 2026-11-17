const { neon } = require('@neondatabase/serverless');
const { getDatabaseUrl } = require('./_lib/config');
const { attachRequestId } = require('./_lib/request_id');

function createReadinessHandler(probeDatabase, logger = console.error) {
  return async function ready(req, res) {
    const requestId = attachRequestId(res);
    res.setHeader('Cache-Control', 'no-store');
    if (req.method !== 'GET') {
      res.setHeader('Allow', 'GET');
      return res.status(405).json({ error: 'method_not_allowed' });
    }

    try {
      await probeDatabase();
      return res.status(200).json({
        status: 'ready',
        database: 'connected',
      });
    } catch (error) {
      const errorCode =
        error && typeof error === 'object' && typeof error.code === 'string'
          ? error.code
          : undefined;
      logger('Database readiness check failed.', {
        requestId,
        errorName: error instanceof Error ? error.name : 'UnknownError',
        ...(errorCode ? { errorCode } : {}),
      });
      return res.status(503).json({
        status: 'not_ready',
        database: 'unavailable',
      });
    }
  };
}

const handler = createReadinessHandler(async () => {
  const sql = neon(getDatabaseUrl());
  await sql`SELECT 1`;
});

module.exports = handler;
module.exports.createReadinessHandler = createReadinessHandler;
