# Database migrations

Migration files are forward-only SQL scripts named
`NNNN_short_description.sql` and applied in numerical order. Do not edit a
migration after it has been applied to a shared environment; add a new
migration instead.

The Neon database stores the CRM records. `owner_user_id` is the UUID from
Supabase Auth; it intentionally has no foreign key because Auth is a separate
service/database.

The migrations create the single-owner workspace, scoped JSON records, RLS
policies, owner profile, relational CRM tables, private project-asset metadata,
delivery records, finance documents, line items, templates, invoice-payment
history, encrypted per-workspace communications integrations, communication
history, and idempotent WhatsApp provider events.
It also stores per-owner, fixed-window API rate-limit counters with row-level
security. Expired counters are pruned on authenticated requests.
Authenticated API transactions set the transaction-local `app.user_id` used by
those policies. Do not grant end-user database credentials or bypass RLS from a
client.

The WhatsApp routing function is deliberately restricted to the database role
that applies migrations. It can resolve only the workspace configured for the
requested phone-number ID; a narrowly scoped RLS policy supports that lookup.
All subsequent reads and writes run in a transaction with that owner's
`app.user_id` set. If migrations and the API use different database roles,
grant `EXECUTE` on this function only to the API's runtime role after reviewing
the deployment's role setup.

Apply migrations from the project root using `npm run db:migrate`. The runner
uses the local `.env.local` file (or `ENV_FILE` if set), obtains a PostgreSQL
transaction-scoped advisory lock, and applies each migration and its
`schema_migrations` record in one transaction. The transaction-scoped lock is
compatible with Neon pooled connections.

Before applying migrations to a database:

1. Use the development database and review the SQL.
2. Set `DATABASE_URL` only in a trusted environment. For local runs, use the
   ignored `.env.local` file and a development connection string.
3. Confirm the applied version is recorded in `schema_migrations`.
4. Verify the resulting schema before promoting the migration.

Run the same reviewed migration sequence separately against development,
staging, and production databases. Never share a database branch between those
environments.

The runner does not automatically roll back an already-applied migration. Add a
new forward migration to change the schema.
