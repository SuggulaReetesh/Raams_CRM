const fs = require('node:fs');
const path = require('node:path');

const migrationsDirectory = path.join(__dirname, '..', 'database', 'migrations');

function validateMigrationNames(names) {
  const migrations = names.filter((name) => name.endsWith('.sql')).sort();
  if (migrations.length === 0) {
    throw new Error('No SQL migration files were found.');
  }

  migrations.forEach((name, index) => {
    const expectedPrefix = String(index + 1).padStart(4, '0');
    if (!new RegExp(`^${expectedPrefix}_[a-z0-9_]+\\.sql$`).test(name)) {
      throw new Error(
        `Migration "${name}" must use the next version prefix ${expectedPrefix}_.`,
      );
    }
  });

  return migrations;
}

function checkMigrations() {
  const names = fs.readdirSync(migrationsDirectory);
  const migrations = validateMigrationNames(names);
  process.stdout.write(`Validated ${migrations.length} SQL migration(s).\n`);
}

if (require.main === module) {
  try {
    checkMigrations();
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  }
}

module.exports = { validateMigrationNames };
