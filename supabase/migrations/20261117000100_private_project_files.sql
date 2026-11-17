INSERT INTO storage.buckets (
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types
)
VALUES (
    'project-files',
    'project-files',
    false,
    1048576,
    ARRAY[
        'image/jpeg',
        'image/png',
        'image/webp',
        'application/pdf',
        'text/plain',
        'text/csv',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.ms-excel',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    ]::text[]
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    public = false,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS project_files_owner_read ON storage.objects;
CREATE POLICY project_files_owner_read
    ON storage.objects
    FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'project-files'
        AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
    );

DROP POLICY IF EXISTS project_files_owner_upload ON storage.objects;
CREATE POLICY project_files_owner_upload
    ON storage.objects
    FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'project-files'
        AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
    );

DROP POLICY IF EXISTS project_files_owner_delete ON storage.objects;
CREATE POLICY project_files_owner_delete
    ON storage.objects
    FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'project-files'
        AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
    );
