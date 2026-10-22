-- ============================================================================
-- MIGRATION 001: LIFTING LIFE — COMPLETE PRODUCTION DATABASE SCHEMA
-- Owner: AI Agent 1 (Backend, Auth, Database, Storage & Security Architect)
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. ENUM TYPES
DO $$ BEGIN
    CREATE TYPE user_role_type AS ENUM ('user', 'creator', 'moderator', 'admin', 'owner');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE experience_level_type AS ENUM ('beginner', 'intermediate', 'advanced');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE training_interest_type AS ENUM ('bodybuilding', 'powerlifting', 'hybrid', 'general_fitness');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE course_status_type AS ENUM ('draft', 'pending_review', 'changes_requested', 'approved', 'rejected', 'archived');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE report_status_type AS ENUM ('open', 'investigating', 'resolved', 'dismissed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE record_provenance_type AS ENUM ('production_verified', 'catalog_seed', 'development_test', 'demo_seed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================================
-- 2. AUTHENTICATION & USER TABLES (profiles, user_preferences, account_settings, user_roles)
-- ============================================================================

CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    email_verified BOOLEAN NOT NULL DEFAULT FALSE,
    username TEXT NOT NULL CHECK (char_length(username) >= 3 AND char_length(username) <= 30),
    display_name TEXT NOT NULL,
    avatar_storage_path TEXT,
    bio TEXT NOT NULL DEFAULT '',
    age INT CHECK (age IS NULL OR (age >= 13 AND age <= 120)),
    height_cm NUMERIC(5,2) CHECK (height_cm IS NULL OR (height_cm >= 50 AND height_cm <= 280)),
    weight_kg NUMERIC(5,2) CHECK (weight_kg IS NULL OR (weight_kg >= 20 AND weight_kg <= 450)),
    tiktok_username TEXT,
    xp_points INT NOT NULL DEFAULT 0 CHECK (xp_points >= 0),
    streak_days INT NOT NULL DEFAULT 0 CHECK (streak_days >= 0),
    onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE,
    provenance record_provenance_type NOT NULL DEFAULT 'production_verified',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Case-insensitive unique username constraint
CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_username_lower ON profiles (LOWER(username));

CREATE TABLE IF NOT EXISTS user_preferences (
    user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
    experience_level experience_level_type NOT NULL DEFAULT 'beginner',
    training_interest training_interest_type NOT NULL DEFAULT 'hybrid',
    workout_frequency TEXT NOT NULL DEFAULT '4 days per week',
    preferred_days TEXT[] NOT NULL DEFAULT '{Mon,Tue,Thu,Fri}',
    training_goals TEXT[] NOT NULL DEFAULT '{}',
    units TEXT NOT NULL DEFAULT 'metric' CHECK (units IN ('metric', 'imperial')),
    default_rest_seconds INT NOT NULL DEFAULT 90 CHECK (default_rest_seconds BETWEEN 15 AND 600),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS account_settings (
    user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
    is_public_profile BOOLEAN NOT NULL DEFAULT TRUE,
    hide_personal_records BOOLEAN NOT NULL DEFAULT FALSE,
    notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    quiet_hours_start TIME NOT NULL DEFAULT '22:00',
    quiet_hours_end TIME NOT NULL DEFAULT '07:00',
    mfa_required BOOLEAN NOT NULL DEFAULT FALSE,
    linked_providers TEXT[] NOT NULL DEFAULT '{email}',
    blocked_user_ids UUID[] NOT NULL DEFAULT '{}',
    deletion_requested_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Server-controlled RBAC table: New accounts ALWAYS default to 'user'
CREATE TABLE IF NOT EXISTS user_roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    role user_role_type NOT NULL DEFAULT 'user',
    assigned_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 3. FITNESS TABLES (exercises, exercise_muscles, exercise_media, workout_templates,
--    workout_sessions, workout_exercises, workout_sets, personal_records, training_programs)
-- ============================================================================

CREATE TABLE IF NOT EXISTS exercises (
    id TEXT PRIMARY KEY, -- Stable Exercise ID (e.g., 'ex_bb_back_squat') for AI Agent 2 integration
    name TEXT UNIQUE NOT NULL,
    category TEXT NOT NULL,
    equipment TEXT NOT NULL,
    equipment_id TEXT NOT NULL DEFAULT 'eq_standard_barbell',
    machine_id TEXT,
    difficulty experience_level_type NOT NULL DEFAULT 'intermediate',
    movement_pattern TEXT NOT NULL,
    suggested_sets INT NOT NULL DEFAULT 3 CHECK (suggested_sets BETWEEN 1 AND 20),
    suggested_reps TEXT NOT NULL DEFAULT '8-12',
    rest_seconds INT NOT NULL DEFAULT 90 CHECK (rest_seconds BETWEEN 0 AND 900),
    instructions TEXT[] NOT NULL DEFAULT '{}',
    technique_tips TEXT[] NOT NULL DEFAULT '{}',
    common_mistakes TEXT[] NOT NULL DEFAULT '{}',
    alternative_exercise_ids TEXT[] NOT NULL DEFAULT '{}',
    start_position_desc TEXT NOT NULL DEFAULT '',
    end_position_desc TEXT NOT NULL DEFAULT '',
    movement_path_desc TEXT NOT NULL DEFAULT '',
    is_powerlifting_competition BOOLEAN NOT NULL DEFAULT FALSE,
    is_powerlifting_variation BOOLEAN NOT NULL DEFAULT FALSE,
    provenance record_provenance_type NOT NULL DEFAULT 'catalog_seed',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS exercise_muscles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    exercise_id TEXT NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
    muscle_id TEXT NOT NULL,
    muscle_name TEXT NOT NULL,
    activation_role TEXT NOT NULL CHECK (activation_role IN ('primary', 'secondary', 'stabilizer')),
    highlight_hex TEXT NOT NULL DEFAULT '#39FF14',
    UNIQUE(exercise_id, muscle_id)
);

CREATE TABLE IF NOT EXISTS exercise_media (
    id TEXT PRIMARY KEY, -- Stable Media Asset ID
    exercise_id TEXT NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
    asset_type TEXT NOT NULL CHECK (asset_type IN ('video_mp4', 'anatomy_glb', 'equipment_glb', 'machine_glb', 'thumbnail_webp')),
    storage_bucket TEXT NOT NULL,
    storage_object_path TEXT NOT NULL,
    version TEXT NOT NULL DEFAULT 'v1',
    license_source TEXT NOT NULL DEFAULT 'gym-animations.com',
    redistributable BOOLEAN NOT NULL DEFAULT FALSE,
    checksum_sha256 TEXT,
    file_size_bytes BIGINT CHECK (file_size_bytes IS NULL OR file_size_bytes > 0),
    duration_ms INT,
    default_camera_view TEXT NOT NULL DEFAULT 'Front',
    is_verified BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(storage_bucket, storage_object_path)
);

CREATE TABLE IF NOT EXISTS user_saved_exercises (
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    exercise_id TEXT NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
    saved_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, exercise_id)
);

CREATE TABLE IF NOT EXISTS workout_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    training_mode training_interest_type NOT NULL DEFAULT 'bodybuilding',
    exercises_json JSONB NOT NULL DEFAULT '[]',
    notes TEXT,
    is_public BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS workout_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    template_id UUID REFERENCES workout_templates(id) ON DELETE SET NULL,
    client_idempotency_key TEXT NOT NULL, -- Prevents duplicate workout submissions during offline sync
    name TEXT NOT NULL,
    training_mode training_interest_type NOT NULL DEFAULT 'bodybuilding',
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    duration_minutes INT NOT NULL DEFAULT 0 CHECK (duration_minutes >= 0 AND duration_minutes <= 720),
    total_volume_kg NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (total_volume_kg >= 0),
    total_sets INT NOT NULL DEFAULT 0 CHECK (total_sets >= 0),
    total_reps INT NOT NULL DEFAULT 0 CHECK (total_reps >= 0),
    is_draft BOOLEAN NOT NULL DEFAULT FALSE,
    notes TEXT,
    provenance record_provenance_type NOT NULL DEFAULT 'production_verified',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, client_idempotency_key)
);

CREATE TABLE IF NOT EXISTS workout_exercises (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES workout_sessions(id) ON DELETE CASCADE,
    exercise_id TEXT NOT NULL REFERENCES exercises(id) ON DELETE RESTRICT,
    exercise_name TEXT NOT NULL,
    muscle_group TEXT NOT NULL,
    order_index INT NOT NULL DEFAULT 0,
    rest_timer_seconds INT NOT NULL DEFAULT 90,
    notes TEXT
);

CREATE TABLE IF NOT EXISTS workout_sets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workout_exercise_id UUID NOT NULL REFERENCES workout_exercises(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    set_number INT NOT NULL CHECK (set_number >= 1 AND set_number <= 100),
    weight_kg NUMERIC(6,2) NOT NULL DEFAULT 0 CHECK (weight_kg >= 0 AND weight_kg <= 600),
    reps INT NOT NULL DEFAULT 0 CHECK (reps >= 0 AND reps <= 250),
    rpe NUMERIC(3,1) CHECK (rpe IS NULL OR (rpe >= 1.0 AND rpe <= 10.0)),
    rir INT CHECK (rir IS NULL OR (rir >= 0 AND rir <= 10)),
    is_warmup BOOLEAN NOT NULL DEFAULT FALSE,
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    rest_seconds INT NOT NULL DEFAULT 90,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS personal_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    exercise_id TEXT NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
    exercise_name TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'General',
    weight_kg NUMERIC(6,2) NOT NULL CHECK (weight_kg > 0 AND weight_kg <= 600),
    reps INT NOT NULL CHECK (reps > 0 AND reps <= 100),
    estimated_1rm NUMERIC(6,2) NOT NULL CHECK (estimated_1rm > 0),
    is_competition_lift BOOLEAN NOT NULL DEFAULT FALSE,
    workout_session_id UUID REFERENCES workout_sessions(id) ON DELETE SET NULL,
    achieved_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS training_programs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    creator_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    mode training_interest_type NOT NULL,
    split_type TEXT NOT NULL,
    difficulty experience_level_type NOT NULL,
    weeks_duration INT NOT NULL DEFAULT 8 CHECK (weeks_duration BETWEEN 1 AND 52),
    days_per_week INT NOT NULL DEFAULT 4 CHECK (days_per_week BETWEEN 1 AND 7),
    description TEXT NOT NULL,
    deload_guidance TEXT NOT NULL,
    recovery_guidance TEXT NOT NULL,
    is_featured BOOLEAN NOT NULL DEFAULT FALSE,
    is_custom BOOLEAN NOT NULL DEFAULT FALSE,
    provenance record_provenance_type NOT NULL DEFAULT 'catalog_seed',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS program_days (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    program_id UUID NOT NULL REFERENCES training_programs(id) ON DELETE CASCADE,
    day_number INT NOT NULL,
    title TEXT NOT NULL,
    focus_muscles TEXT[] NOT NULL DEFAULT '{}',
    prescriptions JSONB NOT NULL DEFAULT '[]'
);

-- ============================================================================
-- 4. SOCIAL & LEADERBOARD TABLES (friendships, follows, posts, rankings, achievements, challenges)
-- ============================================================================

CREATE TABLE IF NOT EXISTS friendships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    requester_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    addressee_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'blocked')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (requester_id != addressee_id),
    UNIQUE(requester_id, addressee_id)
);

CREATE TABLE IF NOT EXISTS follows (
    follower_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    following_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (follower_id != following_id),
    PRIMARY KEY (follower_id, following_id)
);

CREATE TABLE IF NOT EXISTS posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    author_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    caption TEXT NOT NULL CHECK (char_length(caption) <= 2000),
    post_type TEXT NOT NULL DEFAULT 'progress',
    media_storage_path TEXT,
    exercise_id TEXT REFERENCES exercises(id) ON DELETE SET NULL,
    workout_session_id UUID REFERENCES workout_sessions(id) ON DELETE SET NULL,
    pr_highlight TEXT,
    likes_count INT NOT NULL DEFAULT 0 CHECK (likes_count >= 0),
    comments_count INT NOT NULL DEFAULT 0 CHECK (comments_count >= 0),
    is_public BOOLEAN NOT NULL DEFAULT TRUE,
    provenance record_provenance_type NOT NULL DEFAULT 'production_verified',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS post_comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL CHECK (char_length(content) BETWEEN 1 AND 1000),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS post_likes (
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (post_id, user_id)
);

-- Authoritative Server-Calculated Rankings Table (Protected from client tampering)
CREATE TABLE IF NOT EXISTS rankings (
    user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
    period_key TEXT NOT NULL DEFAULT 'weekly',
    score_xp INT NOT NULL DEFAULT 0 CHECK (score_xp >= 0),
    weekly_capped_sessions INT NOT NULL DEFAULT 0 CHECK (weekly_capped_sessions BETWEEN 0 AND 5),
    streak_days INT NOT NULL DEFAULT 0 CHECK (streak_days >= 0),
    courses_completed INT NOT NULL DEFAULT 0 CHECK (courses_completed >= 0),
    powerlifting_strength_index NUMERIC(6,2) NOT NULL DEFAULT 0,
    best_pr_summary TEXT NOT NULL DEFAULT 'No competition PRs recorded yet',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS achievements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    badge_code TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    xp_awarded INT NOT NULL DEFAULT 100 CHECK (xp_awarded >= 0),
    unlocked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, badge_code)
);

CREATE TABLE IF NOT EXISTS challenges (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    creator_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    challenge_type TEXT NOT NULL,
    target_sessions INT NOT NULL DEFAULT 4 CHECK (target_sessions BETWEEN 1 AND 30),
    reward_xp INT NOT NULL DEFAULT 250 CHECK (reward_xp BETWEEN 0 AND 2000),
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL,
    is_public BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS challenge_members (
    challenge_id UUID NOT NULL REFERENCES challenges(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    progress_value INT NOT NULL DEFAULT 0 CHECK (progress_value >= 0),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (challenge_id, user_id)
);

-- ============================================================================
-- 5. EDUCATION TABLES (courses, course_lessons, enrollments, lesson_progress,
--    course_submissions, course_approvals)
-- ============================================================================

CREATE TABLE IF NOT EXISTS courses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    creator_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    category TEXT NOT NULL,
    difficulty experience_level_type NOT NULL DEFAULT 'beginner',
    cover_storage_path TEXT,
    status course_status_type NOT NULL DEFAULT 'draft',
    is_premium BOOLEAN NOT NULL DEFAULT FALSE,
    approved_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    approved_at TIMESTAMPTZ,
    reviewer_feedback TEXT,
    rating_avg NUMERIC(3,2) NOT NULL DEFAULT 0.0,
    reviews_count INT NOT NULL DEFAULT 0,
    provenance record_provenance_type NOT NULL DEFAULT 'production_verified',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS course_lessons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    chapter_number INT NOT NULL DEFAULT 1,
    lesson_order INT NOT NULL DEFAULT 1,
    title TEXT NOT NULL,
    duration_minutes INT NOT NULL DEFAULT 10 CHECK (duration_minutes > 0),
    video_storage_path TEXT,
    content_markdown TEXT NOT NULL,
    related_exercise_id TEXT REFERENCES exercises(id) ON DELETE SET NULL,
    quiz_json JSONB NOT NULL DEFAULT '[]'
);

CREATE TABLE IF NOT EXISTS enrollments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    enrolled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    UNIQUE(course_id, user_id)
);

CREATE TABLE IF NOT EXISTS lesson_progress (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    enrollment_id UUID NOT NULL REFERENCES enrollments(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    lesson_id UUID NOT NULL REFERENCES course_lessons(id) ON DELETE CASCADE,
    quiz_score INT CHECK (quiz_score IS NULL OR (quiz_score >= 0 AND quiz_score <= 100)),
    completed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(enrollment_id, lesson_id)
);

CREATE TABLE IF NOT EXISTS course_submissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    submitted_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    status course_status_type NOT NULL DEFAULT 'pending_review',
    submission_notes TEXT,
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS course_approvals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    submission_id UUID REFERENCES course_submissions(id) ON DELETE SET NULL,
    reviewer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
    reviewer_role user_role_type NOT NULL CHECK (reviewer_role IN ('admin', 'owner')),
    decision course_status_type NOT NULL CHECK (decision IN ('approved', 'rejected', 'changes_requested')),
    feedback TEXT NOT NULL,
    decided_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 6. ADMINISTRATION TABLES (notifications, reports, storage_assets, audit_logs)
-- ============================================================================

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    notification_type TEXT NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reporter_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    target_type TEXT NOT NULL CHECK (target_type IN ('post', 'comment', 'user', 'course')),
    target_id TEXT NOT NULL,
    reason TEXT NOT NULL,
    status report_status_type NOT NULL DEFAULT 'open',
    resolved_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    resolution_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS storage_assets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    bucket_id TEXT NOT NULL,
    object_path TEXT NOT NULL,
    content_type TEXT NOT NULL,
    file_size_bytes BIGINT NOT NULL CHECK (file_size_bytes > 0),
    sha256_hash TEXT NOT NULL,
    is_private BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(bucket_id, object_path)
);

CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    actor_id UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
    actor_role user_role_type NOT NULL,
    action TEXT NOT NULL,
    target_type TEXT NOT NULL,
    target_id TEXT NOT NULL,
    details TEXT NOT NULL DEFAULT '',
    metadata JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 7. SERVER-SIDE TRIGGERS: USER PROVISIONING, COURSE APPROVAL & RANKINGS
-- ============================================================================

-- Automatically provision profile, preferences, settings, and 'user' role when auth.users is created
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER AS $$
DECLARE
    raw_username TEXT;
    final_username TEXT;
BEGIN
    raw_username := COALESCE(
        NEW.raw_user_meta_data->>'username',
        SPLIT_PART(COALESCE(NEW.email, 'athlete'), '@', 1)
    );
    raw_username := REGEXP_REPLACE(LOWER(raw_username), '[^a-z0-9_]', '_', 'g');
    IF char_length(raw_username) < 3 THEN
        raw_username := raw_username || '_ath';
    END IF;
    final_username := SUBSTRING(raw_username FROM 1 FOR 22) || '_' || SUBSTRING(REPLACE(NEW.id::text, '-', '') FROM 1 FOR 6);

    INSERT INTO public.profiles (id, email, email_verified, username, display_name)
    VALUES (
        NEW.id,
        COALESCE(NEW.email, final_username || '@privaterelay.appleid.com'),
        (NEW.email_confirmed_at IS NOT NULL),
        final_username,
        COALESCE(NEW.raw_user_meta_data->>'display_name', final_username)
    )
    ON CONFLICT (id) DO UPDATE
    SET email_verified = (EXCLUDED.email_verified OR public.profiles.email_verified),
        updated_at = NOW();

    INSERT INTO public.user_preferences (user_id) VALUES (NEW.id) ON CONFLICT DO NOTHING;
    INSERT INTO public.account_settings (user_id) VALUES (NEW.id) ON CONFLICT DO NOTHING;
    -- CRITICAL SECURITY RULE: Every user starts as 'user', NEVER 'owner' or 'admin'
    INSERT INTO public.user_roles (user_id, role) VALUES (NEW.id, 'user') ON CONFLICT DO NOTHING;
    INSERT INTO public.rankings (user_id) VALUES (NEW.id) ON CONFLICT DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT OR UPDATE OF email_confirmed_at ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();

-- Enforce course approval rules & prevent self-approval
CREATE OR REPLACE FUNCTION public.enforce_course_approval_rules()
RETURNS TRIGGER AS $$
DECLARE
    actor_role user_role_type;
BEGIN
    IF NEW.status IN ('approved', 'rejected', 'changes_requested') AND OLD.status IS DISTINCT FROM NEW.status THEN
        SELECT role INTO actor_role FROM public.user_roles WHERE user_id = auth.uid();

        IF actor_role IS NULL OR actor_role NOT IN ('admin', 'owner') THEN
            RAISE EXCEPTION 'Unauthorized: Only the App Owner or an authorized Admin can approve or reject courses.';
        END IF;

        IF NEW.creator_id = auth.uid() AND actor_role != 'owner' THEN
            RAISE EXCEPTION 'Security Policy Violation: Course creators cannot approve their own courses.';
        END IF;

        IF NEW.status = 'approved' THEN
            NEW.approved_by := auth.uid();
            NEW.approved_at := NOW();
        END IF;

        INSERT INTO public.course_approvals (course_id, reviewer_id, reviewer_role, decision, feedback)
        VALUES (NEW.id, auth.uid(), actor_role, NEW.status, COALESCE(NEW.reviewer_feedback, 'Reviewed by ' || actor_role::text));

        INSERT INTO public.audit_logs (actor_id, actor_role, action, target_type, target_id, details)
        VALUES (auth.uid(), actor_role, 'COURSE_' || UPPER(NEW.status::text), 'course', NEW.id::text, COALESCE(NEW.reviewer_feedback, ''));
    END IF;

    -- Material edits to an approved course by a non-owner require re-review
    IF OLD.status = 'approved' AND (NEW.title != OLD.title OR NEW.description != OLD.description) THEN
        SELECT role INTO actor_role FROM public.user_roles WHERE user_id = auth.uid();
        IF actor_role IS NULL OR actor_role NOT IN ('admin', 'owner') THEN
            NEW.status := 'pending_review';
            NEW.approved_by := NULL;
            NEW.approved_at := NULL;
        END IF;
    END IF;

    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_enforce_course_approval ON public.courses;
CREATE TRIGGER trg_enforce_course_approval
BEFORE UPDATE ON public.courses
FOR EACH ROW EXECUTE FUNCTION public.enforce_course_approval_rules();

-- Authoritative Ranking Score Recalculation Trigger when a workout session is completed
CREATE OR REPLACE FUNCTION public.recalculate_user_ranking_on_workout()
RETURNS TRIGGER AS $$
DECLARE
    weekly_count INT;
    xp_delta INT := 0;
BEGIN
    IF NEW.is_draft = FALSE THEN
        SELECT COUNT(*) INTO weekly_count
        FROM public.workout_sessions
        WHERE user_id = NEW.user_id
          AND is_draft = FALSE
          AND started_at >= date_trunc('week', NOW());

        -- Cap weekly session XP at 5 workouts per week to reward healthy consistency
        IF weekly_count <= 5 THEN
            xp_delta := 150;
        END IF;

        UPDATE public.profiles
        SET xp_points = xp_points + xp_delta,
            streak_days = streak_days + 1,
            updated_at = NOW()
        WHERE id = NEW.user_id;

        INSERT INTO public.rankings (user_id, score_xp, weekly_capped_sessions, streak_days, updated_at)
        VALUES (NEW.user_id, xp_delta, LEAST(weekly_count, 5), 1, NOW())
        ON CONFLICT (user_id) DO UPDATE
        SET score_xp = public.rankings.score_xp + xp_delta,
            weekly_capped_sessions = LEAST(weekly_count, 5),
            streak_days = public.rankings.streak_days + 1,
            updated_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_recalculate_ranking_on_workout ON public.workout_sessions;
CREATE TRIGGER trg_recalculate_ranking_on_workout
AFTER INSERT ON public.workout_sessions
FOR EACH ROW EXECUTE FUNCTION public.recalculate_user_ranking_on_workout();

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_exercises_category ON public.exercises(category);
CREATE INDEX IF NOT EXISTS idx_exercise_media_exercise ON public.exercise_media(exercise_id);
CREATE INDEX IF NOT EXISTS idx_workout_sessions_user_date ON public.workout_sessions(user_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_personal_records_user_ex ON public.personal_records(user_id, exercise_id);
CREATE INDEX IF NOT EXISTS idx_courses_status ON public.courses(status);
CREATE INDEX IF NOT EXISTS idx_posts_created ON public.posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_rankings_score ON public.rankings(score_xp DESC);

