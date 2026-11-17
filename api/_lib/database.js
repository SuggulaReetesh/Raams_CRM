const { Pool } = require('pg');
const { getDatabaseUrl } = require('./config');

let pool;

function getPool(env = process.env) {
  if (!pool) {
    const databaseUrl = getDatabaseUrl(env);
    const databaseHost = new URL(databaseUrl).hostname.toLowerCase();
    const isLocalHost = ['localhost', '127.0.0.1', '[::1]'].includes(
      databaseHost,
    );
    pool = new Pool({
      connectionString: databaseUrl,
      connectionTimeoutMillis: 10000,
      idleTimeoutMillis: 10000,
      max: 5,
      ssl: env.APP_ENV === 'development' && isLocalHost
        ? false
        : { rejectUnauthorized: true },
    });
    pool.on('error', (error) => {
      console.error('Unexpected idle database client error.', {
        errorName: error.name,
        ...(typeof error.code === 'string' ? { errorCode: error.code } : {}),
      });
    });
  }
  return pool;
}

async function withUserTransaction(userId, operation, poolFactory = getPool) {
  const client = await poolFactory().connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT set_config($1, $2, true)', [
      'app.user_id',
      userId,
    ]);
    const result = await operation(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch (rollbackError) {
      throw new AggregateError(
        [error, rollbackError],
        'Database operation failed and could not be rolled back.',
      );
    }
    throw error;
  } finally {
    client.release();
  }
}

module.exports = { getPool, withUserTransaction };
