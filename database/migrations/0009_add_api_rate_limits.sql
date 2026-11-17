CREATE TABLE api_rate_limit_windows (
    owner_user_id uuid NOT NULL,
    scope text NOT NULL,
    window_started_at timestamptz NOT NULL,
    request_count integer NOT NULL,
    PRIMARY KEY (owner_user_id, scope, window_started_at),
    CONSTRAINT api_rate_limit_scope
        CHECK (char_length(scope) BETWEEN 1 AND 80),
    CONSTRAINT api_rate_limit_request_count
        CHECK (request_count > 0)
);

ALTER TABLE api_rate_limit_windows ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_rate_limit_windows FORCE ROW LEVEL SECURITY;
CREATE POLICY api_rate_limit_windows_owner_policy
    ON api_rate_limit_windows
    USING (
        owner_user_id =
            NULLIF(current_setting('app.user_id', true), '')::uuid
    )
    WITH CHECK (
        owner_user_id =
            NULLIF(current_setting('app.user_id', true), '')::uuid
    );
