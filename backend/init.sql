-- Social Media Database Initialization Script
-- Consolidated Schema (Tables, Views, Triggers, Full-Text Search)

-- ============================================
-- 1. CONFIGURATIONS & EXTENSIONS
-- ============================================

-- Install Turkish text search configuration
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_ts_config WHERE cfgname = 'turkish') THEN
        CREATE TEXT SEARCH CONFIGURATION turkish_simple ( COPY = simple );
    END IF;
END $$;

-- Create custom Turkish stop-words dictionary
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_ts_dict WHERE dictname = 'turkish_stopwords') THEN
        CREATE TEXT SEARCH DICTIONARY turkish_stopwords (
            TEMPLATE = simple,
            STOPWORDS = turkish
        );
    END IF;
END $$;

-- Create bilingual (Turkish + English) configuration
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_ts_config WHERE cfgname = 'bilingual_tr_en') THEN
        CREATE TEXT SEARCH CONFIGURATION bilingual_tr_en ( COPY = english );
        ALTER TEXT SEARCH CONFIGURATION bilingual_tr_en
            ALTER MAPPING FOR asciiword, asciihword, hword_asciipart, word, hword, hword_part
            WITH turkish_stem, english_stem;
    END IF;
END $$;

-- ============================================
-- 2. DROP EXISTING TABLES
-- ============================================
DROP TRIGGER IF EXISTS audit_user_deletion ON Users;
DROP TABLE IF EXISTS AuditLog CASCADE;
DROP VIEW IF EXISTS community_statistics_view CASCADE;
DROP VIEW IF EXISTS active_users_view CASCADE;
DROP VIEW IF EXISTS popular_posts_view CASCADE;
DROP VIEW IF EXISTS user_feed_view CASCADE;
DROP TABLE IF EXISTS Messages CASCADE;
DROP TABLE IF EXISTS Comments CASCADE;
DROP TABLE IF EXISTS PostLikes CASCADE;
DROP TABLE IF EXISTS Posts CASCADE;
DROP TABLE IF EXISTS CommunityMembers CASCADE;
DROP TABLE IF EXISTS Communities CASCADE;
DROP TABLE IF EXISTS Follows CASCADE;
DROP TABLE IF EXISTS Users CASCADE;
DROP TABLE IF EXISTS FollowStatus CASCADE;
DROP TABLE IF EXISTS PrivacyTypes CASCADE;
DROP TABLE IF EXISTS Roles CASCADE;

-- ============================================
-- 3. CREATE LOOKUP/REFERENCE TABLES
-- ============================================

CREATE TABLE Roles (
    role_id SERIAL PRIMARY KEY,
    role_name VARCHAR(20) UNIQUE NOT NULL
);

CREATE TABLE PrivacyTypes (
    privacy_id SERIAL PRIMARY KEY,
    privacy_name VARCHAR(20) UNIQUE NOT NULL
);

CREATE TABLE FollowStatus (
    status_id SERIAL PRIMARY KEY,
    status_name VARCHAR(20) UNIQUE NOT NULL
);

-- ============================================
-- 4. CREATE MAIN ENTITY TABLES
-- ============================================

CREATE TABLE Users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    bio TEXT,
    profile_picture_url TEXT,
    is_private BOOLEAN DEFAULT FALSE,
    search_vector tsvector,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE Communities (
    community_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    creator_id INT REFERENCES Users(user_id) ON DELETE CASCADE,
    privacy_id INT REFERENCES PrivacyTypes(privacy_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE AuditLog (
    audit_id SERIAL PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    operation VARCHAR(20) NOT NULL,
    user_id INT,
    username VARCHAR(50),
    email VARCHAR(100),
    record_data JSONB,
    deleted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_by INT,
    reason TEXT
);

-- ============================================
-- 5. CREATE RELATIONSHIP/JUNCTION TABLES
-- ============================================

CREATE TABLE CommunityMembers (
    community_id INT REFERENCES Communities(community_id) ON DELETE CASCADE,
    user_id INT REFERENCES Users(user_id) ON DELETE CASCADE,
    role_id INT REFERENCES Roles(role_id),
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (community_id, user_id)
);

CREATE TABLE Follows (
    follower_id INT REFERENCES Users(user_id) ON DELETE CASCADE,
    following_id INT REFERENCES Users(user_id) ON DELETE CASCADE,
    status_id INT REFERENCES FollowStatus(status_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (follower_id, following_id)
);

-- ============================================
-- 6. CREATE CONTENT TABLES
-- ============================================

CREATE TABLE Posts (
    post_id SERIAL PRIMARY KEY,
    user_id INT REFERENCES Users(user_id) ON DELETE CASCADE,
    community_id INT REFERENCES Communities(community_id),
    content TEXT,
    media_url TEXT,
    search_vector tsvector,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE Comments (
    comment_id SERIAL PRIMARY KEY,
    post_id INT REFERENCES Posts(post_id) ON DELETE CASCADE,
    user_id INT REFERENCES Users(user_id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    parent_comment_id INT REFERENCES Comments(comment_id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE PostLikes (
    post_id INT REFERENCES Posts(post_id) ON DELETE CASCADE,
    user_id INT REFERENCES Users(user_id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (post_id, user_id)
);

CREATE TABLE Messages (
    message_id SERIAL PRIMARY KEY,
    sender_id INT REFERENCES Users(user_id) ON DELETE CASCADE,
    receiver_id INT REFERENCES Users(user_id) ON DELETE CASCADE,
    content TEXT,
    media_url TEXT,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 7. FUNCTIONS (Triggers & Search)
-- ============================================

-- Generic updated_at timestamp function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Audit Logging Function
CREATE OR REPLACE FUNCTION log_user_deletion()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO AuditLog (
        table_name, operation, user_id, username, email, record_data, deleted_at
    ) VALUES (
        'Users', 'DELETE', OLD.user_id, OLD.username, OLD.email,
        jsonb_build_object(
            'user_id', OLD.user_id,
            'username', OLD.username,
            'email', OLD.email,
            'bio', OLD.bio,
            'profile_picture_url', OLD.profile_picture_url,
            'is_private', OLD.is_private,
            'created_at', OLD.created_at,
            'updated_at', OLD.updated_at
        ),
        CURRENT_TIMESTAMP
    );
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Search Vector Update (Bilingual) - Posts
CREATE OR REPLACE FUNCTION posts_search_vector_update_turkish()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := 
        setweight(to_tsvector('bilingual_tr_en', COALESCE(NEW.content, '')), 'A');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Search Vector Update (Bilingual) - Users
CREATE OR REPLACE FUNCTION users_search_vector_update_turkish()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := 
        setweight(to_tsvector('bilingual_tr_en', COALESCE(NEW.username, '')), 'A') ||
        setweight(to_tsvector('bilingual_tr_en', COALESCE(NEW.bio, '')), 'B');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Search Function: Posts (Simple)
CREATE OR REPLACE FUNCTION search_posts_simple(
    search_query TEXT,
    search_language regconfig DEFAULT 'english',
    max_results INT DEFAULT 50
)
RETURNS TABLE (
    post_id INT, user_id INT, username VARCHAR(50), content TEXT, media_url TEXT,
    community_id INT, community_name VARCHAR(100), created_at TIMESTAMP,
    like_count BIGINT, comment_count BIGINT, relevance_rank REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.post_id, p.user_id, u.username, p.content, p.media_url,
        p.community_id, c.name AS community_name, p.created_at,
        COALESCE(lc.like_count, 0) AS like_count,
        COALESCE(cc.comment_count, 0) AS comment_count,
        ts_rank(p.search_vector, plainto_tsquery(search_language, search_query)) AS relevance_rank
    FROM Posts p
    JOIN Users u ON p.user_id = u.user_id
    LEFT JOIN Communities c ON p.community_id = c.community_id
    LEFT JOIN (SELECT pl.post_id, COUNT(*) AS like_count FROM PostLikes pl GROUP BY pl.post_id) lc ON p.post_id = lc.post_id
    LEFT JOIN (SELECT cm.post_id, COUNT(*) AS comment_count FROM Comments cm GROUP BY cm.post_id) cc ON p.post_id = cc.post_id
    WHERE p.search_vector @@ plainto_tsquery(search_language, search_query)
    ORDER BY relevance_rank DESC, p.created_at DESC
    LIMIT max_results;
END;
$$ LANGUAGE plpgsql;

-- Search Function: Posts (Turkish wrapper)
CREATE OR REPLACE FUNCTION search_posts_turkish(search_query TEXT, max_results INT DEFAULT 50)
RETURNS TABLE (
    post_id INT, user_id INT, username VARCHAR(50), content TEXT, media_url TEXT,
    community_id INT, community_name VARCHAR(100), created_at TIMESTAMP,
    like_count BIGINT, comment_count BIGINT, relevance_rank REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM search_posts_simple(search_query, 'turkish'::regconfig, max_results);
END;
$$ LANGUAGE plpgsql;

-- Search Function: Users
CREATE OR REPLACE FUNCTION search_users(
    search_query TEXT, search_language regconfig DEFAULT 'english', max_results INT DEFAULT 50
)
RETURNS TABLE (
    user_id INT, username VARCHAR(50), email VARCHAR(100), bio TEXT,
    profile_picture_url TEXT, is_private BOOLEAN, created_at TIMESTAMP,
    follower_count BIGINT, following_count BIGINT, post_count BIGINT, relevance_rank REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.user_id, u.username, u.email, u.bio, u.profile_picture_url, u.is_private, u.created_at,
        COALESCE(followers.count, 0) AS follower_count,
        COALESCE(following.count, 0) AS following_count,
        COALESCE(posts.count, 0) AS post_count,
        ts_rank(u.search_vector, plainto_tsquery(search_language, search_query)) AS relevance_rank
    FROM Users u
    LEFT JOIN (SELECT f.following_id, COUNT(*) AS count FROM Follows f WHERE f.status_id = (SELECT status_id FROM FollowStatus WHERE status_name = 'accepted') GROUP BY f.following_id) followers ON u.user_id = followers.following_id
    LEFT JOIN (SELECT f.follower_id, COUNT(*) AS count FROM Follows f WHERE f.status_id = (SELECT status_id FROM FollowStatus WHERE status_name = 'accepted') GROUP BY f.follower_id) following ON u.user_id = following.follower_id
    LEFT JOIN (SELECT p.user_id, COUNT(*) AS count FROM Posts p GROUP BY p.user_id) posts ON u.user_id = posts.user_id
    WHERE u.search_vector @@ plainto_tsquery(search_language, search_query)
    ORDER BY relevance_rank DESC, u.username ASC
    LIMIT max_results;
END;
$$ LANGUAGE plpgsql;

-- Search Function: Users (Turkish wrapper)
CREATE OR REPLACE FUNCTION search_users_turkish(search_query TEXT, max_results INT DEFAULT 50)
RETURNS TABLE (
    user_id INT, username VARCHAR(50), email VARCHAR(100), bio TEXT,
    profile_picture_url TEXT, is_private BOOLEAN, created_at TIMESTAMP,
    follower_count BIGINT, following_count BIGINT, post_count BIGINT, relevance_rank REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM search_users(search_query, 'turkish'::regconfig, max_results);
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 8. TRIGGERS
-- ============================================

-- Updated At Triggers
CREATE TRIGGER update_users_modtime BEFORE UPDATE ON Users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_posts_modtime BEFORE UPDATE ON Posts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_comments_modtime BEFORE UPDATE ON Comments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Audit Trigger
CREATE TRIGGER audit_user_deletion BEFORE DELETE ON Users FOR EACH ROW EXECUTE FUNCTION log_user_deletion();

-- Search Vector Triggers (User Bilingual)
CREATE TRIGGER posts_search_vector_trigger BEFORE INSERT OR UPDATE OF content ON Posts FOR EACH ROW EXECUTE FUNCTION posts_search_vector_update_turkish();
CREATE TRIGGER users_search_vector_trigger BEFORE INSERT OR UPDATE OF username, bio ON Users FOR EACH ROW EXECUTE FUNCTION users_search_vector_update_turkish();

-- ============================================
-- 9. VIEWS
-- ============================================

-- User Feed View
CREATE OR REPLACE VIEW user_feed_view AS
SELECT 
    p.post_id, p.user_id AS author_id, u.username AS author_username,
    u.profile_picture_url AS author_profile_picture,
    p.content, p.media_url, p.community_id, c.name AS community_name,
    p.created_at, p.updated_at,
    COALESCE(like_counts.like_count, 0) AS like_count,
    COALESCE(comment_counts.comment_count, 0) AS comment_count,
    f.follower_id AS viewing_user_id
FROM Posts p
JOIN Users u ON p.user_id = u.user_id
JOIN Follows f ON p.user_id = f.following_id
LEFT JOIN Communities c ON p.community_id = c.community_id
LEFT JOIN (SELECT post_id, COUNT(*) AS like_count FROM PostLikes GROUP BY post_id) like_counts ON p.post_id = like_counts.post_id
LEFT JOIN (SELECT post_id, COUNT(*) AS comment_count FROM Comments GROUP BY post_id) comment_counts ON p.post_id = comment_counts.post_id
WHERE f.status_id = (SELECT status_id FROM FollowStatus WHERE status_name = 'accepted')
ORDER BY p.created_at DESC;

-- Popular Posts View
CREATE OR REPLACE VIEW popular_posts_view AS
SELECT 
    p.post_id, p.user_id, u.username, u.profile_picture_url,
    p.content, p.media_url, p.community_id, c.name AS community_name,
    p.created_at, p.updated_at,
    COALESCE(like_counts.like_count, 0) AS like_count,
    COALESCE(comment_counts.comment_count, 0) AS comment_count,
    (COALESCE(like_counts.like_count, 0) + (COALESCE(comment_counts.comment_count, 0) * 2)) AS engagement_score,
    (p.created_at > NOW() - INTERVAL '7 days') AS is_recent
FROM Posts p
JOIN Users u ON p.user_id = u.user_id
LEFT JOIN Communities c ON p.community_id = c.community_id
LEFT JOIN (SELECT post_id, COUNT(*) AS like_count FROM PostLikes GROUP BY post_id) like_counts ON p.post_id = like_counts.post_id
LEFT JOIN (SELECT post_id, COUNT(*) AS comment_count FROM Comments GROUP BY post_id) comment_counts ON p.post_id = comment_counts.post_id
ORDER BY engagement_score DESC, p.created_at DESC;

-- Active Users View
CREATE OR REPLACE VIEW active_users_view AS
SELECT 
    u.user_id, u.username, u.email, u.profile_picture_url, u.bio, u.created_at AS joined_at,
    COALESCE(post_counts.post_count, 0) AS posts_last_7_days,
    COALESCE(like_counts.like_count, 0) AS likes_last_7_days,
    COALESCE(comment_counts.comment_count, 0) AS comments_last_7_days,
    (COALESCE(post_counts.post_count, 0) + COALESCE(like_counts.like_count, 0) + COALESCE(comment_counts.comment_count, 0)) AS total_activity,
    GREATEST(COALESCE(post_counts.last_post, '1970-01-01'::timestamp), COALESCE(like_counts.last_like, '1970-01-01'::timestamp), COALESCE(comment_counts.last_comment, '1970-01-01'::timestamp)) AS last_activity_at
FROM Users u
LEFT JOIN (SELECT user_id, COUNT(*) AS post_count, MAX(created_at) AS last_post FROM Posts WHERE created_at > NOW() - INTERVAL '7 days' GROUP BY user_id) post_counts ON u.user_id = post_counts.user_id
LEFT JOIN (SELECT user_id, COUNT(*) AS like_count, MAX(created_at) AS last_like FROM PostLikes WHERE created_at > NOW() - INTERVAL '7 days' GROUP BY user_id) like_counts ON u.user_id = like_counts.user_id
LEFT JOIN (SELECT user_id, COUNT(*) AS comment_count, MAX(created_at) AS last_comment FROM Comments WHERE created_at > NOW() - INTERVAL '7 days' GROUP BY user_id) comment_counts ON u.user_id = comment_counts.user_id
WHERE post_counts.post_count > 0 OR like_counts.like_count > 0 OR comment_counts.comment_count > 0
ORDER BY total_activity DESC, last_activity_at DESC;

-- Community Statistics View
CREATE OR REPLACE VIEW community_statistics_view AS
SELECT 
    c.community_id, c.name AS community_name, c.description, c.creator_id, creator.username AS creator_username, c.created_at,
    COALESCE(member_counts.total_members, 0) AS total_members,
    COALESCE(member_counts.admin_count, 0) AS admin_count,
    COALESCE(member_counts.moderator_count, 0) AS moderator_count,
    COALESCE(member_counts.member_count, 0) AS regular_member_count,
    COALESCE(post_counts.total_posts, 0) AS total_posts,
    COALESCE(post_counts.posts_last_7_days, 0) AS posts_last_7_days,
    COALESCE(engagement.total_likes, 0) AS total_likes,
    COALESCE(engagement.total_comments, 0) AS total_comments,
    CASE WHEN post_counts.posts_last_7_days > 0 THEN 'active' ELSE 'inactive' END AS activity_level
FROM Communities c
JOIN Users creator ON c.creator_id = creator.user_id
LEFT JOIN (SELECT cm.community_id, COUNT(*) AS total_members, COUNT(*) FILTER (WHERE r.role_name = 'admin') AS admin_count, COUNT(*) FILTER (WHERE r.role_name = 'moderator') AS moderator_count, COUNT(*) FILTER (WHERE r.role_name = 'member') AS member_count FROM CommunityMembers cm LEFT JOIN Roles r ON cm.role_id = r.role_id GROUP BY cm.community_id) member_counts ON c.community_id = member_counts.community_id
LEFT JOIN (SELECT community_id, COUNT(*) AS total_posts, COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '7 days') AS posts_last_7_days FROM Posts GROUP BY community_id) post_counts ON c.community_id = post_counts.community_id
LEFT JOIN (SELECT p.community_id, COUNT(pl.*) AS total_likes, COUNT(DISTINCT co.comment_id) AS total_comments FROM Posts p LEFT JOIN PostLikes pl ON p.post_id = pl.post_id LEFT JOIN Comments co ON p.post_id = co.post_id WHERE p.community_id IS NOT NULL GROUP BY p.community_id) engagement ON c.community_id = engagement.community_id
ORDER BY total_members DESC;

-- ============================================
-- 10. INDEXES
-- ============================================

-- Standard performance indexes
CREATE INDEX idx_users_username ON Users(username);
CREATE INDEX idx_users_email ON Users(email);
CREATE INDEX idx_posts_user_id ON Posts(user_id);
CREATE INDEX idx_posts_community_id ON Posts(community_id);
CREATE INDEX idx_posts_created_at ON Posts(created_at DESC);
CREATE INDEX idx_comments_post_id ON Comments(post_id);
CREATE INDEX idx_comments_user_id ON Comments(user_id);
CREATE INDEX idx_postlikes_post_id ON PostLikes(post_id);
CREATE INDEX idx_follows_follower_id ON Follows(follower_id);
CREATE INDEX idx_follows_following_id ON Follows(following_id);
CREATE INDEX IF NOT EXISTS idx_follows_follower_status ON Follows(follower_id, status_id);
CREATE INDEX IF NOT EXISTS idx_follows_following_status ON Follows(following_id, status_id);

-- AuditLog Indexes
CREATE INDEX idx_audit_log_table_operation ON AuditLog(table_name, operation);
CREATE INDEX idx_audit_log_user_id ON AuditLog(user_id);
CREATE INDEX idx_audit_log_deleted_at ON AuditLog(deleted_at);

-- GIN Indexes for Search
CREATE INDEX idx_posts_search_vector ON Posts USING GIN(search_vector);
CREATE INDEX idx_users_search_vector ON Users USING GIN(search_vector);

-- ============================================
-- 11. INITIAL SEED DATA
-- ============================================

INSERT INTO Roles (role_name) VALUES ('admin'), ('moderator'), ('member') ON CONFLICT DO NOTHING;
INSERT INTO PrivacyTypes (privacy_name) VALUES ('public'), ('private') ON CONFLICT DO NOTHING;
INSERT INTO FollowStatus (status_name) VALUES ('pending'), ('accepted'), ('rejected') ON CONFLICT DO NOTHING;

-- Seed Users (Password is 'password')
INSERT INTO Users (username, email, password_hash, bio, is_private) VALUES
('admin_user', 'admin@example.com', 'scrypt:32768:8:1$pB4nhPRWoFXQm03K$58d93f935525b56770be3f28f1c1f5e1a240426fd440bad16a46dbc15d984fc32f167835e756e291068a2fca3e68975808bc7bf5028d9346fce26dca78f3b9a8', 'System Administrator', FALSE),
('john_doe', 'john@example.com', 'scrypt:32768:8:1$pB4nhPRWoFXQm03K$58d93f935525b56770be3f28f1c1f5e1a240426fd440bad16a46dbc15d984fc32f167835e756e291068a2fca3e68975808bc7bf5028d9346fce26dca78f3b9a8', 'Just a regular guy loving SQL', FALSE),
('jane_smith', 'jane@example.com', 'scrypt:32768:8:1$pB4nhPRWoFXQm03K$58d93f935525b56770be3f28f1c1f5e1a240426fd440bad16a46dbc15d984fc32f167835e756e291068a2fca3e68975808bc7bf5028d9346fce26dca78f3b9a8', 'Photography and Travel', TRUE),
('mehmet_yilmaz', 'mehmet@example.com', 'scrypt:32768:8:1$pB4nhPRWoFXQm03K$58d93f935525b56770be3f28f1c1f5e1a240426fd440bad16a46dbc15d984fc32f167835e756e291068a2fca3e68975808bc7bf5028d9346fce26dca78f3b9a8', 'Yazılım ve Teknoloji', FALSE)
ON CONFLICT DO NOTHING;

-- Seed Communities
INSERT INTO Communities (name, description, creator_id, privacy_id) VALUES
('Python Lovers', 'A community for Python enthusiasts', (SELECT user_id FROM Users WHERE username='admin_user'), (SELECT privacy_id FROM PrivacyTypes WHERE privacy_name='public')),
('Travel Diaries', 'Share your travel stories', (SELECT user_id FROM Users WHERE username='jane_smith'), (SELECT privacy_id FROM PrivacyTypes WHERE privacy_name='public')),
('Secret Society', 'Invite only', (SELECT user_id FROM Users WHERE username='john_doe'), (SELECT privacy_id FROM PrivacyTypes WHERE privacy_name='private'))
ON CONFLICT DO NOTHING;

-- Seed Community Members
INSERT INTO CommunityMembers (community_id, user_id, role_id) VALUES
((SELECT community_id FROM Communities WHERE name='Python Lovers'), (SELECT user_id FROM Users WHERE username='john_doe'), (SELECT role_id FROM Roles WHERE role_name='member')),
((SELECT community_id FROM Communities WHERE name='Python Lovers'), (SELECT user_id FROM Users WHERE username='mehmet_yilmaz'), (SELECT role_id FROM Roles WHERE role_name='moderator'))
ON CONFLICT DO NOTHING;

-- Seed Follows
INSERT INTO Follows (follower_id, following_id, status_id) VALUES
((SELECT user_id FROM Users WHERE username='john_doe'), (SELECT user_id FROM Users WHERE username='jane_smith'), (SELECT status_id FROM FollowStatus WHERE status_name='pending')),
((SELECT user_id FROM Users WHERE username='jane_smith'), (SELECT user_id FROM Users WHERE username='john_doe'), (SELECT status_id FROM FollowStatus WHERE status_name='accepted'))
ON CONFLICT DO NOTHING;

-- Seed Posts
INSERT INTO Posts (user_id, community_id, content) VALUES
((SELECT user_id FROM Users WHERE username='john_doe'), (SELECT community_id FROM Communities WHERE name='Python Lovers'), 'Just started learning Python, it is amazing!'),
((SELECT user_id FROM Users WHERE username='jane_smith'), (SELECT community_id FROM Communities WHERE name='Travel Diaries'), 'Visiting Istanbul this summer!'),
((SELECT user_id FROM Users WHERE username='mehmet_yilmaz'), NULL, 'Veritabanı optimizasyonu hakkında ipuçları.')
ON CONFLICT DO NOTHING;

-- Seed Comments
INSERT INTO Comments (post_id, user_id, content) VALUES
((SELECT post_id FROM Posts WHERE content LIKE 'Just started learning%'), (SELECT user_id FROM Users WHERE username='mehmet_yilmaz'), 'Welcome to the community!'),
((SELECT post_id FROM Posts WHERE content LIKE 'Visiting Istanbul%'), (SELECT user_id FROM Users WHERE username='john_doe'), 'Have fun! Eat some Baklava.')
ON CONFLICT DO NOTHING;

