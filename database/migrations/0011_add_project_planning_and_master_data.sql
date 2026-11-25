ALTER TABLE workspace_records
    DROP CONSTRAINT workspace_records_collection;

ALTER TABLE workspace_records
    ADD CONSTRAINT workspace_records_collection CHECK (
        collection IN (
            'customers',
            'activities',
            'personas',
            'pipelineStages',
            'projects',
            'phases',
            'tasks',
            'milestones',
            'punchItems',
            'assets',
            'workLogs',
            'attendance',
            'approvals',
            'materials',
            'vendors',
            'quotations',
            'templates',
            'proposals',
            'invoices',
            'communications'
        )
    );

ALTER TABLE studio_projects
    ADD COLUMN start_date date,
    ADD COLUMN budget numeric(15, 2),
    ADD CONSTRAINT studio_projects_budget_range
        CHECK (budget IS NULL OR budget BETWEEN 0 AND 1000000000000),
    ADD CONSTRAINT studio_projects_schedule_order
        CHECK (start_date IS NULL OR target_date IS NULL OR start_date <= target_date);

CREATE TABLE project_phases (
    workspace_id uuid NOT NULL,
    id text NOT NULL,
    project_id text NOT NULL,
    name text NOT NULL,
    position integer NOT NULL CHECK (position >= 0),
    status text NOT NULL,
    start_date date,
    end_date date,
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT project_phases_project_fk
        FOREIGN KEY (workspace_id, project_id)
        REFERENCES studio_projects (workspace_id, id)
        ON DELETE CASCADE,
    CONSTRAINT project_phases_status
        CHECK (status IN ('Not started', 'In progress', 'Complete')),
    CONSTRAINT project_phases_name_length
        CHECK (char_length(btrim(name)) BETWEEN 1 AND 120),
    CONSTRAINT project_phases_date_order
        CHECK (start_date IS NULL OR end_date IS NULL OR start_date <= end_date),
    CONSTRAINT project_phases_position_unique
        UNIQUE (workspace_id, project_id, position),
    CONSTRAINT project_phases_project_id_unique
        UNIQUE (workspace_id, project_id, id)
);

ALTER TABLE project_milestones
    ADD COLUMN phase_id text,
    ADD CONSTRAINT project_milestones_phase_fk
        FOREIGN KEY (workspace_id, project_id, phase_id)
        REFERENCES project_phases (workspace_id, project_id, id)
        ON DELETE SET NULL (phase_id);

CREATE TABLE project_task_dependencies (
    workspace_id uuid NOT NULL,
    project_id text NOT NULL,
    task_id text NOT NULL,
    depends_on_task_id text NOT NULL,
    PRIMARY KEY (workspace_id, task_id, depends_on_task_id),
    CONSTRAINT project_task_dependencies_task_fk
        FOREIGN KEY (workspace_id, project_id, task_id)
        REFERENCES project_tasks (workspace_id, project_id, id)
        ON DELETE CASCADE,
    CONSTRAINT project_task_dependencies_dependency_fk
        FOREIGN KEY (workspace_id, project_id, depends_on_task_id)
        REFERENCES project_tasks (workspace_id, project_id, id)
        ON DELETE CASCADE,
    CONSTRAINT project_task_dependencies_no_self_reference
        CHECK (task_id <> depends_on_task_id)
);

CREATE INDEX project_phases_workspace_project_position_idx
    ON project_phases (workspace_id, project_id, position);
CREATE UNIQUE INDEX project_phases_name_unique_idx
    ON project_phases (workspace_id, project_id, lower(name));
CREATE INDEX project_task_dependencies_workspace_project_idx
    ON project_task_dependencies (workspace_id, project_id, task_id);

DO $$
DECLARE
    table_name text;
BEGIN
    FOREACH table_name IN ARRAY ARRAY[
        'project_phases',
        'project_task_dependencies'
    ]
    LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', table_name);
        EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', table_name);
        EXECUTE format(
            'CREATE POLICY %I ON %I USING (
                workspace_id =
                    NULLIF(current_setting(''app.workspace_id'', true), '''')::uuid
            ) WITH CHECK (
                workspace_id =
                    NULLIF(current_setting(''app.workspace_id'', true), '''')::uuid
            )',
            table_name || '_member_policy',
            table_name
        );
    END LOOP;
END
$$;
