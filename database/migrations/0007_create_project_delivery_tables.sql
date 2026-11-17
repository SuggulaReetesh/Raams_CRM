CREATE TABLE project_tasks (
    workspace_id uuid NOT NULL,
    id text NOT NULL,
    project_id text NOT NULL,
    title text NOT NULL,
    assignee text NOT NULL DEFAULT '',
    due_date date,
    is_complete boolean NOT NULL DEFAULT false,
    priority text NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT project_tasks_project_id_unique
        UNIQUE (workspace_id, project_id, id),
    CONSTRAINT project_tasks_project_fk
        FOREIGN KEY (workspace_id, project_id)
        REFERENCES studio_projects (workspace_id, id)
        ON DELETE CASCADE,
    CONSTRAINT project_tasks_priority
        CHECK (priority IN ('Low', 'Normal', 'High')),
    CONSTRAINT project_tasks_title_length
        CHECK (char_length(btrim(title)) BETWEEN 1 AND 200)
);

CREATE TABLE project_milestones (
    workspace_id uuid NOT NULL,
    id text NOT NULL,
    project_id text NOT NULL,
    title text NOT NULL,
    due_date date,
    status text NOT NULL,
    update_note text NOT NULL DEFAULT '',
    updated_at timestamptz NOT NULL,
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT project_milestones_project_fk
        FOREIGN KEY (workspace_id, project_id)
        REFERENCES studio_projects (workspace_id, id)
        ON DELETE CASCADE,
    CONSTRAINT project_milestones_status
        CHECK (status IN ('Not started', 'In progress', 'Complete')),
    CONSTRAINT project_milestones_title_length
        CHECK (char_length(btrim(title)) BETWEEN 1 AND 200)
);

CREATE TABLE project_punch_items (
    workspace_id uuid NOT NULL,
    id text NOT NULL,
    project_id text NOT NULL,
    description text NOT NULL,
    assignee text NOT NULL DEFAULT '',
    due_date date,
    status text NOT NULL,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT project_punch_items_project_fk
        FOREIGN KEY (workspace_id, project_id)
        REFERENCES studio_projects (workspace_id, id)
        ON DELETE CASCADE,
    CONSTRAINT project_punch_items_status
        CHECK (status IN ('Open', 'In progress', 'Resolved')),
    CONSTRAINT project_punch_items_description_length
        CHECK (char_length(btrim(description)) BETWEEN 1 AND 1000)
);

CREATE TABLE project_work_logs (
    workspace_id uuid NOT NULL,
    id text NOT NULL,
    project_id text NOT NULL,
    task_id text,
    author text NOT NULL,
    minutes integer NOT NULL CHECK (minutes BETWEEN 1 AND 1440),
    description text NOT NULL,
    logged_at timestamptz NOT NULL,
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT project_work_logs_project_fk
        FOREIGN KEY (workspace_id, project_id)
        REFERENCES studio_projects (workspace_id, id)
        ON DELETE CASCADE,
    CONSTRAINT project_work_logs_task_fk
        FOREIGN KEY (workspace_id, project_id, task_id)
        REFERENCES project_tasks (workspace_id, project_id, id)
        ON DELETE SET NULL (task_id),
    CONSTRAINT project_work_logs_description_length
        CHECK (char_length(btrim(description)) BETWEEN 1 AND 1000)
);

CREATE TABLE project_attendance (
    workspace_id uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
    id text NOT NULL,
    persona_id text NOT NULL,
    persona_name text NOT NULL,
    attendance_date date NOT NULL,
    status text NOT NULL,
    note text NOT NULL DEFAULT '',
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT project_attendance_status
        CHECK (status IN ('Present', 'Remote', 'Late', 'Away')),
    CONSTRAINT project_attendance_persona_name_length
        CHECK (char_length(btrim(persona_name)) BETWEEN 1 AND 120)
);

CREATE UNIQUE INDEX project_attendance_persona_date_unique_idx
    ON project_attendance (workspace_id, persona_id, attendance_date);

CREATE TABLE project_approval_requests (
    workspace_id uuid NOT NULL,
    id text NOT NULL,
    project_id text NOT NULL,
    related_proposal_id text,
    title text NOT NULL,
    details text NOT NULL DEFAULT '',
    requested_by text NOT NULL,
    approver_persona_id text NOT NULL,
    approver_name text NOT NULL,
    status text NOT NULL,
    decision_note text NOT NULL DEFAULT '',
    requested_at timestamptz NOT NULL,
    decided_at timestamptz,
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT project_approval_requests_project_fk
        FOREIGN KEY (workspace_id, project_id)
        REFERENCES studio_projects (workspace_id, id)
        ON DELETE CASCADE,
    CONSTRAINT project_approval_requests_status
        CHECK (status IN ('Pending', 'Approved', 'Rejected')),
    CONSTRAINT project_approval_requests_decision_state
        CHECK (
            (status = 'Pending' AND decided_at IS NULL) OR
            (status <> 'Pending' AND decided_at IS NOT NULL)
        ),
    CONSTRAINT project_approval_requests_title_length
        CHECK (char_length(btrim(title)) BETWEEN 1 AND 200)
);

CREATE INDEX project_tasks_workspace_project_idx
    ON project_tasks (workspace_id, project_id, due_date);
CREATE INDEX project_milestones_workspace_project_idx
    ON project_milestones (workspace_id, project_id, due_date);
CREATE INDEX project_punch_items_workspace_project_idx
    ON project_punch_items (workspace_id, project_id, due_date);
CREATE INDEX project_work_logs_workspace_project_time_idx
    ON project_work_logs (workspace_id, project_id, logged_at DESC);
CREATE INDEX project_approval_requests_workspace_project_idx
    ON project_approval_requests (workspace_id, project_id, requested_at DESC);

ALTER TABLE project_assets
    ADD CONSTRAINT project_assets_name_length
        CHECK (char_length(btrim(name)) BETWEEN 1 AND 255),
    ADD CONSTRAINT project_assets_caption_length
        CHECK (char_length(caption) <= 1000),
    ADD CONSTRAINT project_assets_added_by_length
        CHECK (char_length(btrim(added_by)) BETWEEN 1 AND 120);

DO $$
DECLARE
    table_name text;
BEGIN
    FOREACH table_name IN ARRAY ARRAY[
        'project_tasks',
        'project_milestones',
        'project_punch_items',
        'project_work_logs',
        'project_attendance',
        'project_approval_requests'
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
