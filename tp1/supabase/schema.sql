-- ============================================================================
-- LIFTING LIFE — COMPLETE PRODUCTION DATABASE SCHEMA (PostgreSQL / Supabase)
-- Train. Progress. Compete. Inspire.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. ENUM TYPES
CREATE TYPE user_role_type AS ENUM ('user', 'creator', 'moderator', 'admin', 'owner');
CREATE TYPE experience_level_type AS ENUM ('beginner', 'intermediate', 'advanced');
CREATE TYPE training_interest_type AS ENUM ('bodybuilding', 'powerlifting', 'hybrid');
CREATE TYPE course_status_type AS ENUM ('draft', 'pending_review', 'changes_requested', 'approved', 'rejected', 'archived');
CREATE TYPE report_status_type AS ENUM ('open', 'investigating', 'resolved', 'dismissed');

-- 2. USERS, LINKED AUTH PROVIDERS & PROFILES
CREATE TABLE users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    email_verified BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_login_at TIMESTAMPTZ
);

-- Managed OAuth / Identity Provider Links (Email, Facebook OAuth, Apple ID)
-- Never stores raw passwords or OAuth secrets; references Supabase auth.identities
CREATE TABLE linked_auth_providers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider TEXT NOT NULL CHECK (provider IN ('email', 'facebook', 'apple')),
    provider_subject_id TEXT NOT NULL,
    provider_email TEXT,
    is_private_relay BOOLEAN NOT NULL DEFAULT FALSE,
    linked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(provider, provider_subject_id),
    UNIQUE(user_id, provider)
);

CREATE TABLE user_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL CHECK (char_length(username) >= 3 AND char_length(username) <= 30),
    display_name TEXT NOT NULL,
    avatar_url TEXT,
    bio TEXT DEFAULT '',
    experience_level experience_level_type NOT NULL DEFAULT 'beginner',
    training_interest training_interest_type NOT NULL DEFAULT 'hybrid',
    preferred_training_days INT[] DEFAULT '{1,3,5}',
    training_goals TEXT[] DEFAULT '{}',
    tiktok_username TEXT,
    units TEXT NOT NULL DEFAULT 'metric' CHECK (units IN ('metric', 'imperial')),
    is_public_profile BOOLEAN NOT NULL DEFAULT TRUE,
    hide_personal_records BOOLEAN NOT NULL DEFAULT FALSE,
    is_premium BOOLEAN NOT NULL DEFAULT FALSE,
    xp_points INT NOT NULL DEFAULT 0 CHECK (xp_points >= 0),
    level INT NOT NULL DEFAULT 1 CHECK (level >= 1),
    quiet_hours_start TIME DEFAULT '22:00',
    quiet_hours_end TIME DEFAULT '07:00',
    notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. USER ROLES (Server-Side RBAC - Protected from client self-promotion)
CREATE TABLE user_roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role user_role_type NOT NULL DEFAULT 'user',
    assigned_by UUID REFERENCES users(id),
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id)
);

-- 4. EXERCISES, MUSCLES & 3D ANIMATIONS
CREATE TABLE exercises (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT UNIQUE NOT NULL,
    category TEXT NOT NULL,
    equipment TEXT NOT NULL,
    difficulty experience_level_type NOT NULL DEFAULT 'intermediate',
    suggested_sets INT NOT NULL DEFAULT 3,
    suggested_reps TEXT NOT NULL DEFAULT '8-12',
    rest_seconds INT NOT NULL DEFAULT 90,
    instructions TEXT[] NOT NULL DEFAULT '{}',
    technique_tips TEXT[] NOT NULL DEFAULT '{}',
    common_mistakes TEXT[] NOT NULL DEFAULT '{}',
    alternative_exercise_ids UUID[] DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE exercise_muscles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    exercise_id UUID NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
    muscle_name TEXT NOT NULL,
    is_primary BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE exercise_animations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    exercise_id UUID UNIQUE NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
    glb_model_url TEXT,
    movement_pattern TEXT NOT NULL,
    start_position_desc TEXT NOT NULL,
    end_position_desc TEXT NOT NULL,
    movement_path_desc TEXT NOT NULL,
    is_verified BOOLEAN NOT NULL DEFAULT TRUE
);

-- 5. WORKOUT TEMPLATES, SESSIONS, EXERCISES, SETS & PERSONAL RECORDS
CREATE TABLE workout_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'Custom',
    notes TEXT,
    is_public BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE workout_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    template_id UUID REFERENCES workout_templates(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    training_mode training_interest_type NOT NULL DEFAULT 'bodybuilding',
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    duration_seconds INT NOT NULL DEFAULT 0,
    total_volume_kg NUMERIC(10,2) NOT NULL DEFAULT 0,
    total_sets INT NOT NULL DEFAULT 0,
    total_reps INT NOT NULL DEFAULT 0,
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    notes TEXT
);

CREATE TABLE workout_exercises (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES workout_sessions(id) ON DELETE CASCADE,
    exercise_id UUID NOT NULL REFERENCES exercises(id) ON DELETE RESTRICT,
    order_index INT NOT NULL DEFAULT 0,
    rest_timer_seconds INT NOT NULL DEFAULT 90,
    notes TEXT
);

CREATE TABLE workout_sets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workout_exercise_id UUID NOT NULL REFERENCES workout_exercises(id) ON DELETE CASCADE,
    set_number INT NOT NULL,
    weight_kg NUMERIC(6,2) NOT NULL DEFAULT 0 CHECK (weight_kg >= 0 AND weight_kg <= 1500),
    reps INT NOT NULL DEFAULT 0 CHECK (reps >= 0 AND reps <= 500),
    rpe NUMERIC(3,1) CHECK (rpe >= 1.0 AND rpe <= 10.0),
    rir INT CHECK (rir >= 0 AND rir <= 10),
    is_warmup BOOLEAN NOT NULL DEFAULT FALSE,
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    rest_seconds INT DEFAULT 90,
    notes TEXT
);

CREATE TABLE personal_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    exercise_id UUID NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
    weight_kg NUMERIC(6,2) NOT NULL,
    reps INT NOT NULL,
    estimated_1rm NUMERIC(6,2) NOT NULL,
    is_competition_lift BOOLEAN NOT NULL DEFAULT FALSE,
    achieved_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. TRAINING PROGRAMS (BODYBUILDING & POWERLIFTING)
CREATE TABLE training_programs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    creator_id UUID REFERENCES users(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    mode training_interest_type NOT NULL,
    split_type TEXT NOT NULL,
    difficulty experience_level_type NOT NULL,
    weeks_duration INT NOT NULL DEFAULT 8,
    days_per_week INT NOT NULL DEFAULT 4,
    description TEXT NOT NULL,
    deload_guidance TEXT NOT NULL,
    recovery_guidance TEXT NOT NULL,
    is_featured BOOLEAN NOT NULL DEFAULT FALSE,
    is_custom BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE program_days (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    program_id UUID NOT NULL REFERENCES training_programs(id) ON DELETE CASCADE,
    day_number INT NOT NULL,
    title TEXT NOT NULL,
    focus_muscles TEXT[] NOT NULL DEFAULT '{}',
    prescriptions JSONB NOT NULL DEFAULT '[]'
);

-- 7. FITNESS COURSES, LESSONS, SUBMISSIONS & MANDATORY OWNER APPROVAL
CREATE TABLE courses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    creator_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    category TEXT NOT NULL,
    difficulty experience_level_type NOT NULL DEFAULT 'beginner',
    cover_image_url TEXT,
    status course_status_type NOT NULL DEFAULT 'draft',
    is_premium BOOLEAN NOT NULL DEFAULT FALSE,
    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMPTZ,
    reviewer_feedback TEXT,
    rating_avg NUMERIC(3,2) NOT NULL DEFAULT 0.0,
    reviews_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE course_lessons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    chapter_number INT NOT NULL DEFAULT 1,
    lesson_order INT NOT NULL DEFAULT 1,
    title TEXT NOT NULL,
    duration_minutes INT NOT NULL DEFAULT 10,
    video_url TEXT,
    content_markdown TEXT NOT NULL,
    related_exercise_id UUID REFERENCES exercises(id) ON DELETE SET NULL,
    quiz_json JSONB NOT NULL DEFAULT '[]'
);

CREATE TABLE course_submissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    submitted_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    status course_status_type NOT NULL DEFAULT 'pending_review',
    reviewer_notes TEXT,
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reviewed_at TIMESTAMPTZ
);

CREATE TABLE course_enrollments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    enrolled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    UNIQUE(course_id, user_id)
);

CREATE TABLE course_progress (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    enrollment_id UUID NOT NULL REFERENCES course_enrollments(id) ON DELETE CASCADE,
    lesson_id UUID NOT NULL REFERENCES course_lessons(id) ON DELETE CASCADE,
    quiz_score INT,
    completed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(enrollment_id, lesson_id)
);

CREATE TABLE course_reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(course_id, user_id)
);

-- 8. SOCIAL COMMUNITY, FRIENDS, CHALLENGES & LEADERBOARDS
CREATE TABLE friendships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    requester_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    addressee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'blocked')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(requester_id, addressee_id)
);

CREATE TABLE follows (
    follower_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    following_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (follower_id, following_id)
);

CREATE TABLE social_posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    author_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    caption TEXT NOT NULL,
    post_type TEXT NOT NULL DEFAULT 'progress',
    video_url TEXT,
    exercise_id UUID REFERENCES exercises(id) ON DELETE SET NULL,
    workout_session_id UUID REFERENCES workout_sessions(id) ON DELETE SET NULL,
    likes_count INT NOT NULL DEFAULT 0,
    comments_count INT NOT NULL DEFAULT 0,
    is_public BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE post_comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID NOT NULL REFERENCES social_posts(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE post_likes (
    post_id UUID NOT NULL REFERENCES social_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (post_id, user_id)
);

CREATE TABLE challenges (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    creator_id UUID REFERENCES users(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    challenge_type TEXT NOT NULL,
    target_sessions INT NOT NULL DEFAULT 4,
    reward_xp INT NOT NULL DEFAULT 250,
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL,
    is_public BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE challenge_members (
    challenge_id UUID NOT NULL REFERENCES challenges(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    progress_value INT NOT NULL DEFAULT 0,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (challenge_id, user_id)
);

CREATE TABLE leaderboards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    owner_id UUID REFERENCES users(id) ON DELETE CASCADE,
    is_private BOOLEAN NOT NULL DEFAULT FALSE,
    invite_code TEXT UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE leaderboard_scores (
    leaderboard_id UUID NOT NULL REFERENCES leaderboards(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    score_xp INT NOT NULL DEFAULT 0,
    weekly_capped_sessions INT NOT NULL DEFAULT 0 CHECK (weekly_capped_sessions <= 5),
    rank_position INT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (leaderboard_id, user_id)
);

-- 9. ACHIEVEMENTS, NOTIFICATIONS, REPORTS & ADMIN AUDIT LOGS
CREATE TABLE achievements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    badge_code TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    xp_awarded INT NOT NULL DEFAULT 100,
    unlocked_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    notification_type TEXT NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_type TEXT NOT NULL CHECK (target_type IN ('post', 'comment', 'user', 'course')),
    target_id UUID NOT NULL,
    reason TEXT NOT NULL,
    status report_status_type NOT NULL DEFAULT 'open',
    resolved_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE admin_audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    actor_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    action TEXT NOT NULL,
    target_type TEXT NOT NULL,
    target_id UUID NOT NULL,
    metadata JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- MANDATORY SERVER-SIDE TRIGGER: COURSE APPROVAL & SELF-APPROVAL PREVENTION
-- ============================================================================
CREATE OR REPLACE FUNCTION enforce_course_approval_rules()
RETURNS TRIGGER AS $$
DECLARE
    actor_role user_role_type;
BEGIN
    -- If status is being set to 'approved', 'rejected', or 'changes_requested'
    IF NEW.status IN ('approved', 'rejected', 'changes_requested') AND OLD.status IS DISTINCT FROM NEW.status THEN
        SELECT role INTO actor_role FROM user_roles WHERE user_id = auth.uid();

        IF actor_role IS NULL OR actor_role NOT IN ('admin', 'owner') THEN
            RAISE EXCEPTION 'Unauthorized: Only the App Owner or an authorized Admin can approve or reject courses.';
        END IF;

        IF NEW.creator_id = auth.uid() AND actor_role != 'owner' THEN
            RAISE EXCEPTION 'Forbidden: Course creators cannot approve their own courses.';
        END IF;

        IF NEW.status = 'approved' THEN
            NEW.approved_by := auth.uid();
            NEW.approved_at := NOW();
        END IF;
    END IF;

    -- If a previously approved course has material edits by its creator, require re-approval
    IF OLD.status = 'approved' AND (NEW.title != OLD.title OR NEW.description != OLD.description) THEN
        SELECT role INTO actor_role FROM user_roles WHERE user_id = auth.uid();
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

CREATE TRIGGER trg_enforce_course_approval
BEFORE UPDATE ON courses
FOR EACH ROW EXECUTE FUNCTION enforce_course_approval_rules();

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================
CREATE INDEX idx_exercises_category ON exercises(category);
CREATE INDEX idx_workout_sessions_user_date ON workout_sessions(user_id, started_at DESC);
CREATE INDEX idx_courses_status ON courses(status);
CREATE INDEX idx_social_posts_created ON social_posts(created_at DESC);
CREATE INDEX idx_leaderboard_scores_xp ON leaderboard_scores(leaderboard_id, score_xp DESC);
CREATE UNIQUE INDEX idx_user_profiles_username_lower ON user_profiles (LOWER(username));

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) ENABLEMENT ON ALL TABLES
-- (Full policies in supabase/migrations/20261021000002_row_level_security_policies.sql)
-- ============================================================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE linked_auth_providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercise_muscles ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercise_animations ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_sets ENABLE ROW LEVEL SECURITY;
ALTER TABLE personal_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE training_programs ENABLE ROW LEVEL SECURITY;
ALTER TABLE program_days ENABLE ROW LEVEL SECURITY;
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE course_lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE course_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE course_enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE course_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE course_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE social_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE challenge_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE leaderboards ENABLE ROW LEVEL SECURITY;
ALTER TABLE leaderboard_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_audit_logs ENABLE ROW LEVEL SECURITY;


