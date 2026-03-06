-- =============================================================
-- MindBridge Database Schema v1.0
-- PostgreSQL 16+
-- =============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================================
-- USERS & AUTHENTICATION
-- =============================================================

CREATE TABLE users (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email                VARCHAR(255) UNIQUE NOT NULL,
    password_hash        VARCHAR(255) NOT NULL,
    name                 VARCHAR(255) NOT NULL,
    preferred_name       VARCHAR(100),
    university           VARCHAR(255),
    year_of_study        SMALLINT CHECK (year_of_study BETWEEN 1 AND 10),
    profile_image_url    TEXT,
    onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE,
    goals                TEXT[] DEFAULT '{}',
    is_active            BOOLEAN NOT NULL DEFAULT TRUE,
    last_seen_at         TIMESTAMP WITH TIME ZONE,
    created_at           TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_created_at ON users(created_at);

-- Automatic updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- =============================================================
-- SESSIONS (JWT Refresh Tokens)
-- =============================================================

CREATE TABLE sessions (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token        TEXT NOT NULL UNIQUE,
    refresh_token TEXT NOT NULL UNIQUE,
    expires_at   TIMESTAMP WITH TIME ZONE NOT NULL,
    ip_address   INET,
    user_agent   TEXT,
    created_at   TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sessions_user_id ON sessions(user_id);
CREATE INDEX idx_sessions_token ON sessions(token);
CREATE INDEX idx_sessions_refresh_token ON sessions(refresh_token);
CREATE INDEX idx_sessions_expires_at ON sessions(expires_at);

-- =============================================================
-- CHAT SYSTEM
-- =============================================================

CREATE TABLE chat_sessions (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title      VARCHAR(255),
    is_active  BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_chat_sessions_user_id ON chat_sessions(user_id);
CREATE INDEX idx_chat_sessions_updated_at ON chat_sessions(updated_at);

CREATE TRIGGER chat_sessions_updated_at
    BEFORE UPDATE ON chat_sessions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TABLE messages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chat_session_id UUID NOT NULL REFERENCES chat_sessions(id) ON DELETE CASCADE,
    role            VARCHAR(20) NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
    content         TEXT NOT NULL,
    is_crisis_detected BOOLEAN NOT NULL DEFAULT FALSE,
    metadata        JSONB DEFAULT '{}',
    created_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_messages_chat_session_id ON messages(chat_session_id);
CREATE INDEX idx_messages_created_at ON messages(created_at);
CREATE INDEX idx_messages_crisis ON messages(is_crisis_detected) WHERE is_crisis_detected = TRUE;

-- =============================================================
-- MOOD TRACKING
-- =============================================================

CREATE TABLE mood_entries (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    mood_score  SMALLINT NOT NULL CHECK (mood_score BETWEEN 1 AND 10),
    emotions    TEXT[] DEFAULT '{}',
    activities  TEXT[] DEFAULT '{}',
    note        TEXT,
    sleep_hours DECIMAL(4, 1) CHECK (sleep_hours BETWEEN 0 AND 24),
    created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_mood_entries_user_id ON mood_entries(user_id);
CREATE INDEX idx_mood_entries_created_at ON mood_entries(created_at);
CREATE INDEX idx_mood_entries_user_date ON mood_entries(user_id, created_at DESC);

-- View: Daily mood summary per user
CREATE VIEW daily_mood_summary AS
SELECT
    user_id,
    DATE(created_at AT TIME ZONE 'UTC') AS mood_date,
    ROUND(AVG(mood_score), 1) AS avg_mood,
    MIN(mood_score) AS min_mood,
    MAX(mood_score) AS max_mood,
    COUNT(*) AS entry_count,
    AVG(sleep_hours) AS avg_sleep
FROM mood_entries
GROUP BY user_id, DATE(created_at AT TIME ZONE 'UTC');

-- =============================================================
-- JOURNAL
-- =============================================================

CREATE TABLE journal_entries (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title      VARCHAR(255),
    content    TEXT NOT NULL,
    mood_score SMALLINT CHECK (mood_score BETWEEN 1 AND 10),
    tags       TEXT[] DEFAULT '{}',
    is_private BOOLEAN NOT NULL DEFAULT TRUE,
    ai_insight TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_journal_entries_user_id ON journal_entries(user_id);
CREATE INDEX idx_journal_entries_created_at ON journal_entries(created_at);
CREATE INDEX idx_journal_entries_search ON journal_entries
    USING gin(to_tsvector('english', COALESCE(title, '') || ' ' || content));

CREATE TRIGGER journal_entries_updated_at
    BEFORE UPDATE ON journal_entries
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- =============================================================
-- RESOURCES
-- =============================================================

CREATE TABLE resources (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title         VARCHAR(255) NOT NULL,
    description   TEXT,
    content       TEXT,
    resource_type VARCHAR(50) NOT NULL
        CHECK (resource_type IN ('article', 'video', 'exercise', 'hotline', 'book', 'guide')),
    category      VARCHAR(100) NOT NULL,
    tags          TEXT[] DEFAULT '{}',
    url           TEXT,
    thumbnail_url TEXT,
    read_time_min SMALLINT,
    is_featured   BOOLEAN NOT NULL DEFAULT FALSE,
    is_crisis     BOOLEAN NOT NULL DEFAULT FALSE,
    view_count    INTEGER NOT NULL DEFAULT 0,
    created_at    TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_resources_category ON resources(category);
CREATE INDEX idx_resources_featured ON resources(is_featured) WHERE is_featured = TRUE;
CREATE INDEX idx_resources_crisis ON resources(is_crisis) WHERE is_crisis = TRUE;
CREATE INDEX idx_resources_search ON resources
    USING gin(to_tsvector('english', title || ' ' || COALESCE(description, '')));

-- =============================================================
-- COMMUNITY POSTS
-- =============================================================

CREATE TABLE community_posts (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content       TEXT NOT NULL,
    is_anonymous  BOOLEAN NOT NULL DEFAULT TRUE,
    category      VARCHAR(100) DEFAULT 'General',
    tags          TEXT[] DEFAULT '{}',
    likes_count   INTEGER NOT NULL DEFAULT 0,
    comments_count INTEGER NOT NULL DEFAULT 0,
    is_reported   BOOLEAN NOT NULL DEFAULT FALSE,
    is_removed    BOOLEAN NOT NULL DEFAULT FALSE,
    is_pinned     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_community_posts_user_id ON community_posts(user_id);
CREATE INDEX idx_community_posts_created_at ON community_posts(created_at DESC);
CREATE INDEX idx_community_posts_likes ON community_posts(likes_count DESC);
CREATE INDEX idx_community_posts_active ON community_posts(is_removed) WHERE is_removed = FALSE;

CREATE TRIGGER community_posts_updated_at
    BEFORE UPDATE ON community_posts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TABLE post_likes (
    id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(post_id, user_id)
);

CREATE TABLE post_comments (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id    UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content    TEXT NOT NULL,
    is_anonymous BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- =============================================================
-- WELLNESS CHALLENGES & GAMIFICATION
-- =============================================================

CREATE TABLE wellness_challenges (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title          VARCHAR(255) NOT NULL,
    description    TEXT,
    challenge_type VARCHAR(100) NOT NULL
        CHECK (challenge_type IN ('mindfulness', 'journal', 'mood', 'physical', 'social', 'sleep', 'other')),
    icon_emoji     VARCHAR(10),
    duration_days  SMALLINT NOT NULL DEFAULT 1,
    points         SMALLINT NOT NULL DEFAULT 10,
    is_daily       BOOLEAN NOT NULL DEFAULT TRUE,
    is_active      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TABLE user_challenge_completions (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    challenge_id UUID NOT NULL REFERENCES wellness_challenges(id),
    completed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    points_earned SMALLINT NOT NULL,
    UNIQUE(user_id, challenge_id, DATE(completed_at))
);

CREATE INDEX idx_completions_user_id ON user_challenge_completions(user_id);
CREATE INDEX idx_completions_date ON user_challenge_completions(completed_at);

-- User points/streak summary view
CREATE VIEW user_wellness_stats AS
SELECT
    u.id AS user_id,
    COALESCE(SUM(ucc.points_earned), 0) AS total_points,
    COUNT(DISTINCT DATE(me.created_at)) AS mood_log_days,
    COUNT(DISTINCT DATE(je.created_at)) AS journal_days,
    COUNT(DISTINCT ucc.id) AS challenges_completed
FROM users u
LEFT JOIN user_challenge_completions ucc ON ucc.user_id = u.id
LEFT JOIN mood_entries me ON me.user_id = u.id
LEFT JOIN journal_entries je ON je.user_id = u.id
GROUP BY u.id;

-- =============================================================
-- ACHIEVEMENTS / BADGES
-- =============================================================

CREATE TABLE achievements (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    achievement_type VARCHAR(100) NOT NULL,
    title            VARCHAR(255) NOT NULL,
    description      TEXT,
    emoji            VARCHAR(10),
    earned_at        TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_achievements_user_id ON achievements(user_id);

-- =============================================================
-- CRISIS REPORTING (ANONYMIZED)
-- =============================================================

CREATE TABLE crisis_events (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID REFERENCES users(id) ON DELETE SET NULL,
    severity         VARCHAR(20) NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    trigger_keywords TEXT[],
    source           VARCHAR(50) NOT NULL CHECK (source IN ('chat', 'mood_log', 'journal')),
    action_taken     VARCHAR(255),
    resources_shown  TEXT[],
    resolved         BOOLEAN NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_crisis_events_user_id ON crisis_events(user_id);
CREATE INDEX idx_crisis_events_severity ON crisis_events(severity);
CREATE INDEX idx_crisis_events_created_at ON crisis_events(created_at);

-- =============================================================
-- COUNSELORS (Professional Help Directory)
-- =============================================================

CREATE TABLE counselors (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name             VARCHAR(255) NOT NULL,
    title            VARCHAR(255),
    university       VARCHAR(255),
    specializations  TEXT[] DEFAULT '{}',
    email            VARCHAR(255),
    phone            VARCHAR(50),
    avatar_url       TEXT,
    is_available     BOOLEAN NOT NULL DEFAULT TRUE,
    booking_url      TEXT,
    created_at       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TABLE counselor_appointments (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    counselor_id  UUID NOT NULL REFERENCES counselors(id),
    scheduled_at  TIMESTAMP WITH TIME ZONE NOT NULL,
    duration_min  SMALLINT NOT NULL DEFAULT 50,
    status        VARCHAR(50) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'confirmed', 'completed', 'cancelled')),
    notes         TEXT,
    created_at    TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- =============================================================
-- NOTIFICATIONS
-- =============================================================

CREATE TABLE notifications (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title      VARCHAR(255) NOT NULL,
    body       TEXT NOT NULL,
    type       VARCHAR(100) NOT NULL
        CHECK (type IN ('mood_reminder', 'journal_prompt', 'challenge', 'achievement', 'crisis_followup', 'general')),
    is_read    BOOLEAN NOT NULL DEFAULT FALSE,
    action_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = FALSE;

-- =============================================================
-- SEED DATA — Wellness Challenges
-- =============================================================

INSERT INTO wellness_challenges (title, description, challenge_type, icon_emoji, points) VALUES
('3-Minute Breathing', 'Complete one breathing exercise session', 'mindfulness', '🫁', 10),
('Gratitude Entry', 'Write 3 things you are grateful for in your journal', 'journal', '📝', 15),
('Mood Log', 'Record your mood and emotions for today', 'mood', '😊', 5),
('Mindful Walk', 'Take a 10-minute walk without your phone', 'physical', '🚶', 20),
('Connect', 'Reach out to one person you care about', 'social', '💬', 25),
('Sleep Hygiene', 'Be in bed before midnight and log your sleep', 'sleep', '😴', 15),
('Positive Affirmation', 'Write one thing you love about yourself', 'journal', '💕', 10),
('No Social Media Hour', 'Spend 1 hour without checking social media', 'mindfulness', '📵', 20),
('5-4-3-2-1 Grounding', 'Practice the grounding technique once today', 'mindfulness', '✋', 15),
('Call a Family Member', 'Connect with a family member today', 'social', '👨‍👩‍👧', 25);

-- =============================================================
-- SEED DATA — Resources
-- =============================================================

INSERT INTO resources (title, description, category, resource_type, is_featured, read_time_min, tags) VALUES
('Understanding Anxiety in Students', 'A comprehensive guide to recognizing and managing academic anxiety.', 'Anxiety', 'article', TRUE, 8, '{"anxiety", "academic", "students"}'),
('The Depression Toolkit', '10 evidence-based strategies for lifting your mood and restoring motivation.', 'Depression', 'article', TRUE, 12, '{"depression", "cbt", "mood"}'),
('Sleep Hygiene for Students', 'How to build a sleep routine that actually works around your study schedule.', 'Sleep', 'article', FALSE, 6, '{"sleep", "routine", "wellness"}'),
('Imposter Syndrome: You Belong Here', 'Overcoming the feeling that you don''t deserve your achievements.', 'Self-Esteem', 'article', TRUE, 10, '{"imposter", "confidence", "academic"}'),
('Crisis: What to Do Right Now', 'Step-by-step guidance for managing a mental health crisis safely.', 'Crisis', 'guide', FALSE, 5, '{"crisis", "emergency", "safety"}');

-- =============================================================
-- ROW LEVEL SECURITY (RLS) — Enable for production
-- =============================================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE mood_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Users can only see their own data
CREATE POLICY users_self_policy ON users
    FOR ALL USING (id = current_setting('app.current_user_id')::uuid);

CREATE POLICY mood_entries_user_policy ON mood_entries
    FOR ALL USING (user_id = current_setting('app.current_user_id')::uuid);

CREATE POLICY journal_entries_user_policy ON journal_entries
    FOR ALL USING (user_id = current_setting('app.current_user_id')::uuid);
