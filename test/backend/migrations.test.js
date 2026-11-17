const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const { runMigrations } = require('../../scripts/migrate');

class FakeClient {
  constructor() {
    this.appliedVersions = new Set();
    this.executedSql = [];
  }

  async query(query, parameters = []) {
    const sql = String(query).trim();
    if (
      sql.startsWith(
        'SELECT version FROM schema_migrations WHERE version = $1',
      )
    ) {
      return {
        rows: this.appliedVersions.has(parameters[0])
          ? [{ version: parameters[0] }]
          : [],
      };
    }
    if (sql.startsWith('INSERT INTO schema_migrations')) {
      this.appliedVersions.add(parameters[0]);
      return { rows: [] };
    }
    this.executedSql.push(sql);
    return { rows: [] };
  }
}

test('migration runner applies each migration once and records its version', async () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'crm-migrations-'));
  const migration = '0001_create_workspaces.sql';
  fs.writeFileSync(
    path.join(directory, migration),
    'CREATE TABLE workspaces (id uuid PRIMARY KEY);',
  );
  const client = new FakeClient();
  const appliedLogs = [];

  try {
    const firstRun = await runMigrations({
      client,
      directory,
      log: (message) => appliedLogs.push(message),
    });
    const secondRun = await runMigrations({
      client,
      directory,
      log: (message) => appliedLogs.push(message),
    });

    assert.deepEqual(firstRun, [migration]);
    assert.deepEqual(secondRun, [migration]);
    assert.equal(
      client.executedSql.filter((sql) => sql.includes('CREATE TABLE workspaces'))
        .length,
      1,
    );
    assert.deepEqual(appliedLogs, [`Applied ${migration}.`]);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test('migration runner rolls back a failed migration and preserves the error', async () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'crm-migrations-'));
  fs.writeFileSync(
    path.join(directory, '0001_create_workspaces.sql'),
    'INVALID SQL;',
  );
  const client = new FakeClient();
  client.query = async function (query, parameters = []) {
    const sql = String(query).trim();
    if (sql === 'INVALID SQL;') throw new Error('syntax error');
    return FakeClient.prototype.query.call(this, query, parameters);
  };

  try {
    await assert.rejects(
      runMigrations({ client, directory, log: () => {} }),
      /syntax error/,
    );
    assert.ok(client.executedSql.includes('ROLLBACK'));
    assert.equal(client.appliedVersions.size, 0);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
