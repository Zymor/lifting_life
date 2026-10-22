-- ============================================================================
-- MIGRATION 002: ROW LEVEL SECURITY (RLS) & ROLE-BASED AUTHORIZATION POLICIES
-- Owner: AI Agent 1 (Backend, Auth, Database, Storage & Security Architect)
-- ============================================================================

-- 1. SECURITY DEFINER ROLE LOOKUP FUNCTIONS
CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS user_role_type AS $$
DECLARE
    found_role user_role_type;
BEGIN
    SELECT role INTO found_role FROM public.user_roles WHERE user_id = auth.uid();
    RETURN COALESCE(found_role, 'user'::user_role_type);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.is_app_owner()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN public.get_current_user_role() = 'owner'::user_role_type;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.is_admin_or_owner()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN public.get_current_user_role() IN ('admin'::user_role_type, 'owner'::user_role_type);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Server-only RPC for the App Owner to assign roles with mandatory audit logging
CREATE OR REPLACE FUNCTION public.assign_user_role_as_owner(
    p_target_user_id UUID,
    p_new_role user_role_type,
    p_reason TEXT
)
RETURNS VOID AS $$
BEGIN
    IF NOT public.is_app_owner() THEN
        RAISE EXCEPTION 'Forbidden: Only the verified App Owner can modify user roles.';
    END IF;

    INSERT INTO public.user_roles (user_id, role, assigned_by, assigned_at)
    VALUES (p_target_user_id, p_new_role, auth.uid(), NOW())
    ON CONFLICT (user_id) DO UPDATE
    SET role = EXCLUDED.role,
        assigned_by = auth.uid(),
        assigned_at = NOW();

    INSERT INTO public.audit_logs (actor_id, actor_role, action, target_type, target_id, details)
    VALUES (
        auth.uid(),
        'owner',
        'ASSIGN_USER_ROLE',
        'user',
        p_target_user_id::text,
        'Assigned role ' || p_new_role::text || ': ' || COALESCE(p_reason, 'Owner administrative action')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 2. ENABLE ROW LEVEL SECURITY ON EVERY TABLE
-- ============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exercise_muscles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exercise_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_saved_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_sets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personal_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_programs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.program_days ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rankings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenge_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lesson_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_approvals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.storage_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 3. STRICT RLS POLICIES: USER-OWNED DATA ISOLATION (User A cannot access User B)
-- ============================================================================

-- profiles: Own profile full access; public profiles readable by authenticated users
CREATE POLICY "profiles_select_own_or_public" ON public.profiles
    FOR SELECT TO authenticated
    USING (
        id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.account_settings s
            WHERE s.user_id = public.profiles.id AND s.is_public_profile = TRUE
        )
    );

CREATE POLICY "profiles_insert_own" ON public.profiles
    FOR INSERT TO authenticated
    WITH CHECK (id = auth.uid());

CREATE POLICY "profiles_update_own" ON public.profiles
    FOR UPDATE TO authenticated
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

-- user_preferences: Strictly owner-isolated
CREATE POLICY "user_preferences_own_all" ON public.user_preferences
    FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- account_settings: Strictly owner-isolated
CREATE POLICY "account_settings_own_all" ON public.account_settings
    FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- user_roles: Users can read their own role; ONLY App Owner can modify roles
CREATE POLICY "user_roles_select_own_or_admin" ON public.user_roles
    FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR public.is_admin_or_owner());

CREATE POLICY "user_roles_modify_owner_only" ON public.user_roles
    FOR ALL TO authenticated
    USING (public.is_app_owner())
    WITH CHECK (public.is_app_owner());

-- exercises, exercise_muscles, exercise_media: Readable by authenticated users; writable only by Admin/Owner
CREATE POLICY "exercises_select_authenticated" ON public.exercises
    FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY "exercises_modify_admin_owner" ON public.exercises
    FOR ALL TO authenticated
    USING (public.is_admin_or_owner())
    WITH CHECK (public.is_admin_or_owner());

CREATE POLICY "exercise_muscles_select_authenticated" ON public.exercise_muscles
    FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY "exercise_muscles_modify_admin_owner" ON public.exercise_muscles
    FOR ALL TO authenticated
    USING (public.is_admin_or_owner())
    WITH CHECK (public.is_admin_or_owner());

CREATE POLICY "exercise_media_select_authenticated" ON public.exercise_media
    FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY "exercise_media_modify_admin_owner" ON public.exercise_media
    FOR ALL TO authenticated
    USING (public.is_admin_or_owner())
    WITH CHECK (public.is_admin_or_owner());

-- user_saved_exercises: Strictly isolated to auth.uid()
CREATE POLICY "user_saved_exercises_own_all" ON public.user_saved_exercises
    FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- workout_templates: Own templates + public templates readable
CREATE POLICY "workout_templates_select" ON public.workout_templates
    FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR is_public = TRUE);

CREATE POLICY "workout_templates_modify_own" ON public.workout_templates
    FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- workout_sessions, workout_exercises, workout_sets: Strictly isolated to auth.uid()
CREATE POLICY "workout_sessions_own_all" ON public.workout_sessions
    FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "workout_exercises_own_all" ON public.workout_exercises
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.workout_sessions ws
            WHERE ws.id = public.workout_exercises.session_id
              AND ws.user_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.workout_sessions ws
            WHERE ws.id = public.workout_exercises.session_id
              AND ws.user_id = auth.uid()
        )
    );

CREATE POLICY "workout_sets_own_all" ON public.workout_sets
    FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- personal_records: Own PRs full access; public PRs visible unless hide_personal_records = TRUE
CREATE POLICY "personal_records_select" ON public.personal_records
    FOR SELECT TO authenticated
    USING (
        user_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.account_settings s
            WHERE s.user_id = public.personal_records.user_id
              AND s.is_public_profile = TRUE
              AND s.hide_personal_records = FALSE
        )
    );

CREATE POLICY "personal_records_modify_own" ON public.personal_records
    FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- training_programs & program_days: Catalog programs readable by all; custom programs isolated to creator
CREATE POLICY "training_programs_select" ON public.training_programs
    FOR SELECT TO authenticated
    USING (is_custom = FALSE OR creator_id = auth.uid() OR public.is_admin_or_owner());

CREATE POLICY "training_programs_insert_own" ON public.training_programs
    FOR INSERT TO authenticated
    WITH CHECK (creator_id = auth.uid() OR public.is_admin_or_owner());

CREATE POLICY "training_programs_update_own" ON public.training_programs
    FOR UPDATE TO authenticated
    USING (creator_id = auth.uid() OR public.is_admin_or_owner())
    WITH CHECK (creator_id = auth.uid() OR public.is_admin_or_owner());

CREATE POLICY "program_days_select" ON public.program_days
    FOR SELECT TO authenticated USING (TRUE);

-- friendships & follows
CREATE POLICY "friendships_select_involved" ON public.friendships
    FOR SELECT TO authenticated
    USING (requester_id = auth.uid() OR addressee_id = auth.uid());

CREATE POLICY "friendships_insert_requester" ON public.friendships
    FOR INSERT TO authenticated
    WITH CHECK (requester_id = auth.uid());

CREATE POLICY "friendships_update_involved" ON public.friendships
    FOR UPDATE TO authenticated
    USING (requester_id = auth.uid() OR addressee_id = auth.uid());

CREATE POLICY "follows_select_authenticated" ON public.follows
    FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY "follows_modify_own" ON public.follows
    FOR ALL TO authenticated
    USING (follower_id = auth.uid())
    WITH CHECK (follower_id = auth.uid());

-- posts, post_comments, post_likes
CREATE POLICY "posts_select_public_or_own" ON public.posts
    FOR SELECT TO authenticated
    USING (is_public = TRUE OR author_id = auth.uid() OR public.is_admin_or_owner());

CREATE POLICY "posts_insert_own" ON public.posts
    FOR INSERT TO authenticated
    WITH CHECK (author_id = auth.uid());

CREATE POLICY "posts_update_delete_own_or_mod" ON public.posts
    FOR ALL TO authenticated
    USING (author_id = auth.uid() OR public.is_admin_or_owner());

CREATE POLICY "post_comments_select" ON public.post_comments
    FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY "post_comments_insert_own" ON public.post_comments
    FOR INSERT TO authenticated
    WITH CHECK (author_id = auth.uid());

CREATE POLICY "post_likes_select" ON public.post_likes
    FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY "post_likes_modify_own" ON public.post_likes
    FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- rankings: Readable by authenticated users; ONLY updated by server triggers / Admin
CREATE POLICY "rankings_select_authenticated" ON public.rankings
    FOR SELECT TO authenticated USING (TRUE);

-- courses & course_lessons: Public sees only 'approved'; Creator sees own drafts; Admin/Owner sees all
CREATE POLICY "courses_select_policy" ON public.courses
    FOR SELECT TO authenticated
    USING (
        status = 'approved'::course_status_type
        OR creator_id = auth.uid()
        OR public.is_admin_or_owner()
    );

-- Creators can never insert a course directly as 'approved'
CREATE POLICY "courses_insert_creator" ON public.courses
    FOR INSERT TO authenticated
    WITH CHECK (
        creator_id = auth.uid()
        AND status IN ('draft'::course_status_type, 'pending_review'::course_status_type)
    );

CREATE POLICY "courses_update_creator_or_admin" ON public.courses
    FOR UPDATE TO authenticated
    USING (creator_id = auth.uid() OR public.is_admin_or_owner());

CREATE POLICY "course_lessons_select_policy" ON public.course_lessons
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.courses c
            WHERE c.id = public.course_lessons.course_id
              AND (c.status = 'approved'::course_status_type OR c.creator_id = auth.uid() OR public.is_admin_or_owner())
        )
    );

CREATE POLICY "course_lessons_modify_creator_or_admin" ON public.course_lessons
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.courses c
            WHERE c.id = public.course_lessons.course_id
              AND (c.creator_id = auth.uid() OR public.is_admin_or_owner())
        )
    );

-- enrollments & lesson_progress: Strictly isolated to enrolled user
CREATE POLICY "enrollments_own_all" ON public.enrollments
    FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "lesson_progress_own_all" ON public.lesson_progress
    FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- course_submissions & course_approvals
CREATE POLICY "course_submissions_select" ON public.course_submissions
    FOR SELECT TO authenticated
    USING (submitted_by = auth.uid() OR public.is_admin_or_owner());

CREATE POLICY "course_submissions_insert" ON public.course_submissions
    FOR INSERT TO authenticated
    WITH CHECK (submitted_by = auth.uid());

CREATE POLICY "course_approvals_select" ON public.course_approvals
    FOR SELECT TO authenticated
    USING (public.is_admin_or_owner());

CREATE POLICY "course_approvals_insert_admin_owner" ON public.course_approvals
    FOR INSERT TO authenticated
    WITH CHECK (public.is_admin_or_owner());

-- notifications, reports, storage_assets, audit_logs
CREATE POLICY "notifications_own_all" ON public.notifications
    FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "reports_insert_authenticated" ON public.reports
    FOR INSERT TO authenticated
    WITH CHECK (reporter_id = auth.uid());

CREATE POLICY "reports_select_own_or_admin" ON public.reports
    FOR SELECT TO authenticated
    USING (reporter_id = auth.uid() OR public.is_admin_or_owner());

CREATE POLICY "reports_update_admin_owner" ON public.reports
    FOR UPDATE TO authenticated
    USING (public.is_admin_or_owner());

CREATE POLICY "storage_assets_own_or_admin" ON public.storage_assets
    FOR SELECT TO authenticated
    USING (is_private = FALSE OR owner_user_id = auth.uid() OR public.is_admin_or_owner());

CREATE POLICY "audit_logs_select_admin_owner" ON public.audit_logs
    FOR SELECT TO authenticated
    USING (public.is_admin_or_owner());

