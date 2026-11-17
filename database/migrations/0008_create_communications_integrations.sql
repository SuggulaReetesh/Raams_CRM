CREATE TABLE workspace_integrations (
    workspace_id uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
    owner_user_id uuid NOT NULL,
    provider text NOT NULL,
    account_id text,
    account_hint text NOT NULL,
    secret_ciphertext bytea NOT NULL,
    secret_iv bytea NOT NULL,
    secret_auth_tag bytea NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, provider),
    CONSTRAINT workspace_integrations_provider
        CHECK (provider IN ('postal', 'whatsapp')),
    CONSTRAINT workspace_integrations_account_hint_length
        CHECK (char_length(btrim(account_hint)) BETWEEN 1 AND 160),
    CONSTRAINT workspace_integrations_owner_fk
        FOREIGN KEY (workspace_id, owner_user_id)
        REFERENCES workspaces (id, owner_user_id)
);

CREATE UNIQUE INDEX workspace_integrations_provider_account_unique_idx
    ON workspace_integrations (provider, account_id)
    WHERE account_id IS NOT NULL;

CREATE TABLE communication_messages (
    workspace_id uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
    id text NOT NULL,
    idempotency_key text NOT NULL,
    channel text NOT NULL,
    direction text NOT NULL,
    status text NOT NULL,
    recipient text NOT NULL DEFAULT '',
    subject text NOT NULL DEFAULT '',
    body text NOT NULL,
    provider_message_id text,
    data jsonb NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT communication_messages_idempotency_unique
        UNIQUE (workspace_id, idempotency_key),
    CONSTRAINT communication_messages_channel
        CHECK (channel IN (
            'Internal note', 'Email', 'WhatsApp', 'Call', 'Meeting', 'Message', 'Other'
        )),
    CONSTRAINT communication_messages_direction
        CHECK (direction IN ('inbound', 'outbound', 'internal')),
    CONSTRAINT communication_messages_status
        CHECK (status IN (
            'Logged', 'Draft', 'Ready to send', 'Queued', 'Sending',
            'Sent', 'Delivered', 'Read', 'Failed', 'Received'
        )),
    CONSTRAINT communication_messages_body_length
        CHECK (char_length(body) BETWEEN 1 AND 5000)
);

CREATE UNIQUE INDEX communication_messages_provider_id_unique_idx
    ON communication_messages (workspace_id, provider_message_id)
    WHERE provider_message_id IS NOT NULL;
CREATE INDEX communication_messages_workspace_created_idx
    ON communication_messages (workspace_id, created_at DESC);

CREATE TABLE communication_provider_events (
    workspace_id uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
    provider text NOT NULL,
    event_id text NOT NULL,
    provider_message_id text,
    event_type text NOT NULL,
    payload_hash text NOT NULL,
    occurred_at timestamptz,
    received_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, provider, event_id),
    CONSTRAINT communication_provider_events_provider
        CHECK (provider IN ('whatsapp')),
    CONSTRAINT communication_provider_events_event_type
        CHECK (char_length(btrim(event_type)) BETWEEN 1 AND 80)
);

CREATE INDEX communication_provider_events_received_idx
    ON communication_provider_events (workspace_id, received_at DESC);

CREATE FUNCTION lookup_whatsapp_workspace(target_account_id text)
RETURNS TABLE (workspace_id uuid, owner_user_id uuid)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    previous_account_id text;
BEGIN
    IF target_account_id IS NULL OR
       target_account_id !~ '^[0-9]{6,32}$' THEN
        RETURN;
    END IF;
    previous_account_id := current_setting('app.whatsapp_account_id', true);
    PERFORM set_config('app.whatsapp_account_id', target_account_id, true);
    RETURN QUERY
    SELECT i.workspace_id, i.owner_user_id
    FROM public.workspace_integrations i
    WHERE i.provider = 'whatsapp'
      AND i.account_id = target_account_id;
    PERFORM set_config(
        'app.whatsapp_account_id',
        COALESCE(previous_account_id, ''),
        true
    );
END
$$;

REVOKE ALL ON FUNCTION lookup_whatsapp_workspace(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION lookup_whatsapp_workspace(text) TO CURRENT_USER;

DO $$
DECLARE
    table_name text;
BEGIN
    FOREACH table_name IN ARRAY ARRAY[
        'communication_messages',
        'communication_provider_events'
    ]
    LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', table_name);
        EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', table_name);
        EXECUTE format(
            'CREATE POLICY %I ON %I USING (
                workspace_id IN (
                    SELECT id FROM workspaces
                    WHERE owner_user_id =
                        NULLIF(current_setting(''app.user_id'', true), '''')::uuid
                )
            ) WITH CHECK (
                workspace_id IN (
                    SELECT id FROM workspaces
                    WHERE owner_user_id =
                        NULLIF(current_setting(''app.user_id'', true), '''')::uuid
                )
            )',
            table_name || '_owner_policy',
            table_name
        );
    END LOOP;
END
$$;

ALTER TABLE workspace_integrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE workspace_integrations FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_integrations_owner_policy
    ON workspace_integrations
    USING (
        owner_user_id =
            NULLIF(current_setting('app.user_id', true), '')::uuid
    )
    WITH CHECK (
        owner_user_id =
            NULLIF(current_setting('app.user_id', true), '')::uuid
    );
CREATE POLICY workspace_integrations_webhook_route
    ON workspace_integrations
    FOR SELECT
    USING (
        provider = 'whatsapp'
        AND account_id =
            NULLIF(current_setting('app.whatsapp_account_id', true), '')
    );
