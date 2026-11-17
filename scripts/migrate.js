const fs = require('node:fs');
const path = require('node:path');
const { Pool } = require('pg');
const dotenv = require('dotenv');
const {
  getDatabaseUrl,
  getRuntimeEnvironment,
} = require('../api/_lib/config');
const { validateMigrationNames } = require('./check-migrations');

const migrationLockKey = 731280145;
const migrationsDirectory = path.join(__dirname, '..', 'database', 'migrations');

async function runMigrations({
  client,
  directory = migrationsDirectory,
  log = console.log,
}) {
  const migrationNames = validateMigrationNames(fs.readdirSync(directory));

  for (const migrationName of migrationNames) {
    await client.query('BEGIN');
    try {
      await client.query('SELECT pg_advisory_xact_lock($1)', [migrationLockKey]);
      await client.query(`
        CREATE TABLE IF NOT EXISTS schema_migrations (
          version text PRIMARY KEY,
          applied_at timestamptz NOT NULL DEFAULT now()
        )
      `);
      const result = await client.query(
        'SELECT version FROM schema_migrations WHERE version = $1',
        [migrationName],
      );
      if (result.rows.length > 0) {
        await client.query('COMMIT');
        continue;
      }

      const migration = fs.readFileSync(
        path.join(directory, migrationName),
        'utf8',
      );
      await client.query(migration);
      await client.query(
        'INSERT INTO schema_migrations (version) VALUES ($1)',
        [migrationName],
      );
      await client.query('COMMIT');
      log(`Applied ${migrationName}.`);
    } catch (error) {
      try {
        await client.query('ROLLBACK');
      } catch (rollbackError) {
        throw new AggregateError(
          [error, rollbackError],
          `Migration ${migrationName} failed and could not be rolled back.`,
        );
      }
      throw error;
    }
  }

  return migrationNames;
}

async function main() {
  dotenv.config({ path: process.env.ENV_FILE || '.env.local' });
  const environment = getRuntimeEnvironment();
  if (
    environment !== 'development' &&
    process.env.CONFIRM_DATABASE_MIGRATION !== environment
  ) {
    throw new Error(
      `Set CONFIRM_DATABASE_MIGRATION=${environment} to run migrations in ${environment}.`,
    );
  }
  const pool = new Pool({
    connectionString: getDatabaseUrl(),
    connectionTimeoutMillis: 10000,
    max: 1,
  });
  let client;

  try {
    client = await pool.connect();
    const applied = await runMigrations({ client });
    process.stdout.write(`Database schema is at ${applied.length} migration(s).\n`);
  } finally {
    if (client) client.release();
    await pool.end();
  }
}

if (require.main === module) {
  main().catch((error) => {
    process.stderr.write(
      `Migration failed: ${error instanceof Error ? error.message : error}\n`,
    );
    process.exitCode = 1;
  });
}

module.exports = { runMigrations };
