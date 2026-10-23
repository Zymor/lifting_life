-- ============================================================================
-- MIGRATION 003: ORGANIZED CLOUD STORAGE BUCKETS & ACCESS CONTROL POLICIES
-- Owner: AI Agent 1 (Backend, Auth, Database, Storage & Security Architect)
-- ============================================================================
-- Required 9 Buckets:
--   1. profile-avatars      -> profile-avatars/{user_id}/{file_id}.webp
--   2. exercise-videos      -> exercise-videos/{exercise_id}/{video_id}.mp4
--   3. anatomy-models       -> anatomy-models/{model_id}/{version}.glb
--   4. exercise-equipment   -> exercise-equipment/{equipment_id}/{version}.glb
--   5. machine-models       -> machine-models/{machine_id}/{version}.glb
--   6. course-media         -> course-media/{course_id}/{lesson_id}/{file_id}
--   7. community-media      -> community-media/{user_id}/{post_id}/{file_id}
--   8. private-user-files   -> private-user-files/{user_id}/{file_id}
--   9. import-staging       -> import-staging/{import_batch_id}/{file_id}
-- ============================================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
    ('profile-avatars',    'profile-avatars',    FALSE, 5242880,   ARRAY['image/webp', 'image/png', 'image/jpeg']),
    ('exercise-videos',    'exercise-videos',    FALSE, 104857600, ARRAY['video/mp4', 'video/webm', 'image/webp']),
    ('anatomy-models',     'anatomy-models',     FALSE, 52428800,  ARRAY['model/gltf-binary', 'model/gltf+json', 'application/octet-stream']),
    ('exercise-equipment', 'exercise-equipment', FALSE, 52428800,  ARRAY['model/gltf-binary', 'model/gltf+json', 'application/octet-stream']),
    ('machine-models',     'machine-models',     FALSE, 52428800,  ARRAY['model/gltf-binary', 'model/gltf+json', 'application/octet-stream']),
    ('course-media',       'course-media',       FALSE, 209715200, ARRAY['video/mp4', 'image/webp', 'image/png', 'application/pdf']),
    ('community-media',    'community-media',    FALSE, 52428800,  ARRAY['video/mp4', 'image/webp', 'image/png', 'image/jpeg']),
    ('private-user-files', 'private-user-files', FALSE, 26214400,  ARRAY['application/json', 'application/pdf', 'image/webp']),
    ('import-staging',     'import-staging',     FALSE, 524288000, ARRAY['video/mp4', 'model/gltf-binary', 'application/json'])
ON CONFLICT (id) DO UPDATE
SET public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- ============================================================================
-- STORAGE OBJECT RLS POLICIES (Prevent cross-user overwrites & unauthorized access)
-- ============================================================================

-- 1. profile-avatars: Users can upload/update/delete ONLY inside profile-avatars/{auth.uid()}/...
CREATE POLICY "profile_avatars_read_authenticated" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'profile-avatars');

CREATE POLICY "profile_avatars_write_own_folder" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'profile-avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "profile_avatars_update_own_folder" ON storage.objects
    FOR UPDATE TO authenticated
    USING (
        bucket_id = 'profile-avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "profile_avatars_delete_own_folder" ON storage.objects
    FOR DELETE TO authenticated
    USING (
        bucket_id = 'profile-avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- 2. exercise-videos, anatomy-models, exercise-equipment, machine-models:
--    Authenticated users read via signed URLs; ONLY Admin/Owner can upload or modify
CREATE POLICY "fitness_3d_and_video_assets_read_authenticated" ON storage.objects
    FOR SELECT TO authenticated
    USING (
        bucket_id IN ('exercise-videos', 'anatomy-models', 'exercise-equipment', 'machine-models')
    );

CREATE POLICY "fitness_3d_and_video_assets_write_admin_owner" ON storage.objects
    FOR ALL TO authenticated
    USING (
        bucket_id IN ('exercise-videos', 'anatomy-models', 'exercise-equipment', 'machine-models')
        AND public.is_admin_or_owner()
    )
    WITH CHECK (
        bucket_id IN ('exercise-videos', 'anatomy-models', 'exercise-equipment', 'machine-models')
        AND public.is_admin_or_owner()
    );

-- 3. course-media: Course creators can upload to their own course folder; enrolled users & admins can read
CREATE POLICY "course_media_read_authorized" ON storage.objects
    FOR SELECT TO authenticated
    USING (
        bucket_id = 'course-media'
        AND (
            public.is_admin_or_owner()
            OR EXISTS (
                SELECT 1 FROM public.courses c
                WHERE c.id::text = (storage.foldername(name))[1]
                  AND (c.status = 'approved'::course_status_type OR c.creator_id = auth.uid())
            )
        )
    );

CREATE POLICY "course_media_write_creator_or_admin" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'course-media'
        AND (
            public.is_admin_or_owner()
            OR EXISTS (
                SELECT 1 FROM public.courses c
                WHERE c.id::text = (storage.foldername(name))[1]
                  AND c.creator_id = auth.uid()
            )
        )
    );

-- 4. community-media: Users can upload ONLY inside community-media/{auth.uid()}/{post_id}/{file_id}
CREATE POLICY "community_media_read_authenticated" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'community-media');

CREATE POLICY "community_media_write_own_folder" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'community-media'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "community_media_delete_own_or_admin" ON storage.objects
    FOR DELETE TO authenticated
    USING (
        bucket_id = 'community-media'
        AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin_or_owner())
    );

-- 5. private-user-files: Strictly isolated to private-user-files/{auth.uid()}/{file_id}
CREATE POLICY "private_user_files_strict_owner_only" ON storage.objects
    FOR ALL TO authenticated
    USING (
        bucket_id = 'private-user-files'
        AND (storage.foldername(name))[1] = auth.uid()::text
    )
    WITH CHECK (
        bucket_id = 'private-user-files'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- 6. import-staging: Strictly Admin / Owner only
CREATE POLICY "import_staging_admin_owner_only" ON storage.objects
    FOR ALL TO authenticated
    USING (
        bucket_id = 'import-staging'
        AND public.is_admin_or_owner()
    )
    WITH CHECK (
        bucket_id = 'import-staging'
        AND public.is_admin_or_owner()
    );

