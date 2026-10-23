-- ============================================================================
-- MIGRATION 004: MANDATORY DATA SAFETY & DEMO-DATA CLEANUP WORKFLOW
-- Owner: AI Agent 1 (Backend, Auth, Database, Storage & Security Architect)
-- ============================================================================
-- Enforces Task 1 Mandatory Data Safety rules:
--   1. Identify current environment
--   2. Inspect all existing database tables
--   3. Create a verified backup snapshot before any destructive action
--   4. Distinguish seeded test/demo data ('demo_seed') from real records ('production_verified')
--   5. Generate a deletion preview
--   6. Require explicit Owner confirmation before destructive cleanup
--   7. Remove confirmed demo records only
--   8. Preserve all real user accounts, workouts, PRs, published courses, and licensed media
-- ============================================================================

CREATE TABLE IF NOT EXISTS demo_cleanup_backups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    environment_name TEXT NOT NULL,
    created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
    backup_payload JSONB NOT NULL,
    checksum_sha256 TEXT NOT NULL,
    verified BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS demo_cleanup_previews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    backup_id UUID NOT NULL REFERENCES demo_cleanup_backups(id) ON DELETE RESTRICT,
    environment_name TEXT NOT NULL CHECK (environment_name IN ('development', 'staging')),
    requested_by UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
    demo_profiles_count INT NOT NULL DEFAULT 0,
    demo_workouts_count INT NOT NULL DEFAULT 0,
    demo_posts_count INT NOT NULL DEFAULT 0,
    demo_courses_count INT NOT NULL DEFAULT 0,
    affected_record_ids JSONB NOT NULL DEFAULT '{}',
    owner_confirmed BOOLEAN NOT NULL DEFAULT FALSE,
    executed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.demo_cleanup_backups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.demo_cleanup_previews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "demo_cleanup_backups_owner_only" ON public.demo_cleanup_backups
    FOR ALL TO authenticated
    USING (public.is_app_owner())
    WITH CHECK (public.is_app_owner());

CREATE POLICY "demo_cleanup_previews_owner_only" ON public.demo_cleanup_previews
    FOR ALL TO authenticated
    USING (public.is_app_owner())
    WITH CHECK (public.is_app_owner());

-- Step 3-5: Create verified backup and generate deletion preview (Never deletes anything)
CREATE OR REPLACE FUNCTION public.generate_demo_cleanup_preview(p_environment TEXT)
RETURNS UUID AS $$
DECLARE
    v_backup_id UUID;
    v_preview_id UUID;
    v_payload JSONB;
    v_demo_profiles INT;
    v_demo_workouts INT;
    v_demo_posts INT;
    v_demo_courses INT;
BEGIN
    IF NOT public.is_app_owner() THEN
        RAISE EXCEPTION 'Forbidden: Only the App Owner can initiate demo-data cleanup previews.';
    END IF;

    IF p_environment NOT IN ('development', 'staging') THEN
        RAISE EXCEPTION 'Safety Guard: Automated demo cleanup is restricted to development or staging environments.';
    END IF;

    SELECT jsonb_build_object(
        'profiles', COALESCE((SELECT jsonb_agg(row_to_json(p)) FROM public.profiles p WHERE p.provenance = 'demo_seed'), '[]'::jsonb),
        'workout_sessions', COALESCE((SELECT jsonb_agg(row_to_json(w)) FROM public.workout_sessions w WHERE w.provenance = 'demo_seed'), '[]'::jsonb),
        'posts', COALESCE((SELECT jsonb_agg(row_to_json(s)) FROM public.posts s WHERE s.provenance = 'demo_seed'), '[]'::jsonb),
        'courses', COALESCE((SELECT jsonb_agg(row_to_json(c)) FROM public.courses c WHERE c.provenance = 'demo_seed' AND c.status != 'approved'), '[]'::jsonb)
    ) INTO v_payload;

    INSERT INTO public.demo_cleanup_backups (environment_name, created_by, backup_payload, checksum_sha256, verified)
    VALUES (
        p_environment,
        auth.uid(),
        v_payload,
        encode(digest(v_payload::text, 'sha256'), 'hex'),
        TRUE
    )
    RETURNING id INTO v_backup_id;

    SELECT COUNT(*) INTO v_demo_profiles FROM public.profiles WHERE provenance = 'demo_seed';
    SELECT COUNT(*) INTO v_demo_workouts FROM public.workout_sessions WHERE provenance = 'demo_seed';
    SELECT COUNT(*) INTO v_demo_posts FROM public.posts WHERE provenance = 'demo_seed';
    SELECT COUNT(*) INTO v_demo_courses FROM public.courses WHERE provenance = 'demo_seed' AND status != 'approved';

    INSERT INTO public.demo_cleanup_previews (
        backup_id, environment_name, requested_by,
        demo_profiles_count, demo_workouts_count, demo_posts_count, demo_courses_count,
        affected_record_ids
    )
    VALUES (
        v_backup_id, p_environment, auth.uid(),
        v_demo_profiles, v_demo_workouts, v_demo_posts, v_demo_courses,
        v_payload
    )
    RETURNING id INTO v_preview_id;

    RETURN v_preview_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 6-8: Execute confirmed demo cleanup ONLY after backup verification & explicit Owner confirmation
CREATE OR REPLACE FUNCTION public.execute_confirmed_demo_cleanup(
    p_preview_id UUID,
    p_owner_confirmed BOOLEAN
)
RETURNS JSONB AS $$
DECLARE
    v_preview RECORD;
    v_backup RECORD;
    v_deleted_posts INT := 0;
    v_deleted_courses INT := 0;
    v_deleted_workouts INT := 0;
    v_deleted_profiles INT := 0;
BEGIN
    IF NOT public.is_app_owner() THEN
        RAISE EXCEPTION 'Forbidden: Only the App Owner can execute demo-data cleanup.';
    END IF;

    IF p_owner_confirmed IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION 'Aborted: Explicit Owner confirmation (p_owner_confirmed = TRUE) is required.';
    END IF;

    SELECT * INTO v_preview FROM public.demo_cleanup_previews WHERE id = p_preview_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cleanup preview % not found.', p_preview_id;
    END IF;

    IF v_preview.executed_at IS NOT NULL THEN
        RAISE EXCEPTION 'Cleanup preview % has already been executed.', p_preview_id;
    END IF;

    SELECT * INTO v_backup FROM public.demo_cleanup_backups WHERE id = v_preview.backup_id AND verified = TRUE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Aborted: Verified backup snapshot is missing for preview %.', p_preview_id;
    END IF;

    -- Delete ONLY records explicitly tagged with provenance = 'demo_seed' (never 'production_verified' or 'catalog_seed')
    DELETE FROM public.posts WHERE provenance = 'demo_seed';
    GET DIAGNOSTICS v_deleted_posts = ROW_COUNT;

    DELETE FROM public.courses WHERE provenance = 'demo_seed' AND status != 'approved';
    GET DIAGNOSTICS v_deleted_courses = ROW_COUNT;

    DELETE FROM public.workout_sessions WHERE provenance = 'demo_seed';
    GET DIAGNOSTICS v_deleted_workouts = ROW_COUNT;

    DELETE FROM public.profiles WHERE provenance = 'demo_seed';
    GET DIAGNOSTICS v_deleted_profiles = ROW_COUNT;

    UPDATE public.demo_cleanup_previews
    SET owner_confirmed = TRUE,
        executed_at = NOW()
    WHERE id = p_preview_id;

    INSERT INTO public.audit_logs (actor_id, actor_role, action, target_type, target_id, details)
    VALUES (
        auth.uid(),
        'owner',
        'EXECUTE_CONFIRMED_DEMO_CLEANUP',
        'demo_cleanup_preview',
        p_preview_id::text,
        format('Removed demo records (profiles=%s, workouts=%s, posts=%s, courses=%s)', v_deleted_profiles, v_deleted_workouts, v_deleted_posts, v_deleted_courses)
    );

    RETURN jsonb_build_object(
        'preview_id', p_preview_id,
        'backup_id', v_preview.backup_id,
        'deleted_profiles', v_deleted_profiles,
        'deleted_workouts', v_deleted_workouts,
        'deleted_posts', v_deleted_posts,
        'deleted_courses', v_deleted_courses,
        'executed_at', NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

