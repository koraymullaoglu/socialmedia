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
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_users_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

CREATE TABLE Communities (
    community_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    creator_id INT REFERENCES Users(user_id) ON DELETE CASCADE,
    privacy_id INT REFERENCES PrivacyTypes(privacy_id),
    member_count INT DEFAULT 0,
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
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_posts_content_or_media CHECK ((content IS NOT NULL AND content != '') OR (media_url IS NOT NULL AND media_url != ''))
);

CREATE TABLE Comments (
    comment_id SERIAL PRIMARY KEY,
    post_id INT REFERENCES Posts(post_id) ON DELETE CASCADE,
    user_id INT REFERENCES Users(user_id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    parent_comment_id INT REFERENCES Comments(comment_id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_comments_min_length CHECK (LENGTH(TRIM(content)) >= 1)
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
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_messages_different_users CHECK (sender_id != receiver_id)
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

-- Member Count Update Trigger Function
CREATE OR REPLACE FUNCTION update_community_member_count()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE Communities
        SET member_count = member_count + 1
        WHERE community_id = NEW.community_id;
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE Communities
        SET member_count = member_count - 1
        WHERE community_id = OLD.community_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
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
-- TRANSACTIONS & ATOMICITY
-- ============================================

-- Function: Create Community with Admin (Atomic)
CREATE OR REPLACE FUNCTION create_community_with_admin(
    p_creator_id INT,
    p_community_name VARCHAR(100),
    p_description TEXT,
    p_is_private BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
    community_id INT,
    creator_id INT,
    community_name VARCHAR(100),
    member_id INT,
    role_name VARCHAR(20),
    status VARCHAR(20)
) AS $$
DECLARE
    v_community_id INT;
    v_admin_role_id INT;
    v_privacy_id INT;
BEGIN
    SELECT r.role_id INTO v_admin_role_id 
    FROM Roles r
    WHERE r.role_name = 'admin';
    
    IF v_admin_role_id IS NULL THEN
        RAISE EXCEPTION 'Admin role not found';
    END IF;
    
    SELECT privacy_id INTO v_privacy_id
    FROM PrivacyTypes
    WHERE privacy_name = CASE WHEN p_is_private THEN 'private' ELSE 'public' END;
    
    INSERT INTO Communities (creator_id, name, description, privacy_id)
    VALUES (p_creator_id, p_community_name, p_description, v_privacy_id)
    RETURNING Communities.community_id INTO v_community_id;
    
    INSERT INTO CommunityMembers (community_id, user_id, role_id)
    VALUES (v_community_id, p_creator_id, v_admin_role_id);
    
    -- Return the results
    RETURN QUERY
    SELECT 
        c.community_id,
        c.creator_id,
        c.name AS community_name,
        cm.user_id AS member_id,
        r.role_name,
        'success'::VARCHAR(20) AS status
    FROM Communities c
    JOIN CommunityMembers cm ON c.community_id = cm.community_id
    JOIN Roles r ON cm.role_id = r.role_id
    WHERE c.community_id = v_community_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- CTE (COMMON TABLE EXPRESSIONS) FUNCTIONS
-- ============================================

-- Function: Get comment thread
CREATE OR REPLACE FUNCTION get_comment_thread(root_post_id INTEGER)
RETURNS TABLE (
    comment_id INTEGER,
    parent_comment_id INTEGER,
    user_id INTEGER,
    username VARCHAR,
    content TEXT,
    created_at TIMESTAMP,
    depth INTEGER,
    path INTEGER[],
    thread_position TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE comment_tree AS (
        SELECT 
            c.comment_id,
            c.parent_comment_id,
            c.user_id,
            u.username,
            c.content,
            c.created_at,
            0 AS depth,
            ARRAY[c.comment_id] AS path,
            c.comment_id::TEXT AS thread_position
        FROM Comments c
        INNER JOIN Users u ON c.user_id = u.user_id
        WHERE c.post_id = root_post_id 
          AND c.parent_comment_id IS NULL
        
        UNION ALL
        
        SELECT 
            c.comment_id,
            c.parent_comment_id,
            c.user_id,
            u.username,
            c.content,
            c.created_at,
            ct.depth + 1,
            ct.path || c.comment_id,
            ct.thread_position || '.' || ROW_NUMBER() OVER (
                PARTITION BY c.parent_comment_id 
                ORDER BY c.created_at
            )::TEXT
        FROM Comments c
        INNER JOIN Users u ON c.user_id = u.user_id
        INNER JOIN comment_tree ct ON c.parent_comment_id = ct.comment_id
        WHERE ct.depth < 10
    )
    SELECT 
        ct.comment_id,
        ct.parent_comment_id,
        ct.user_id,
        ct.username,
        ct.content,
        ct.created_at,
        ct.depth,
        ct.path,
        ct.thread_position
    FROM comment_tree ct
    ORDER BY ct.path;
END;
$$ LANGUAGE plpgsql;

-- Function: Get comment ancestors
CREATE OR REPLACE FUNCTION get_comment_ancestors(target_comment_id INTEGER)
RETURNS TABLE (
    comment_id INTEGER,
    parent_comment_id INTEGER,
    user_id INTEGER,
    username VARCHAR,
    content TEXT,
    depth INTEGER
) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE ancestors AS (
        SELECT 
            c.comment_id,
            c.parent_comment_id,
            c.user_id,
            u.username,
            c.content,
            0 AS depth
        FROM Comments c
        INNER JOIN Users u ON c.user_id = u.user_id
        WHERE c.comment_id = target_comment_id
        
        UNION ALL
        
        SELECT 
            c.comment_id,
            c.parent_comment_id,
            c.user_id,
            u.username,
            c.content,
            a.depth + 1
        FROM Comments c
        INNER JOIN Users u ON c.user_id = u.user_id
        INNER JOIN ancestors a ON c.comment_id = a.parent_comment_id
    )
    SELECT * FROM ancestors
    ORDER BY depth DESC;
END;
$$ LANGUAGE plpgsql;

-- Function: Get friend-of-friend recommendations
CREATE OR REPLACE FUNCTION get_friend_of_friend_recommendations(target_user_id INTEGER)
RETURNS TABLE (
    recommended_user INTEGER,
    username VARCHAR,
    mutual_friends INTEGER,
    connection_strength NUMERIC
) AS $$
DECLARE
    v_accepted_id INT;
BEGIN
    SELECT status_id INTO v_accepted_id FROM FollowStatus WHERE status_name = 'accepted';

    RETURN QUERY
    WITH 
    my_friends AS (
        SELECT following_id AS friend_id
        FROM Follows
        WHERE follower_id = target_user_id
          AND status_id = v_accepted_id
    ),
    friends_of_friends AS (
        SELECT DISTINCT
            f.following_id AS potential_friend,
            mf.friend_id AS mutual_friend
        FROM my_friends mf
        INNER JOIN Follows f ON f.follower_id = mf.friend_id
        WHERE f.status_id = v_accepted_id
          AND f.following_id != target_user_id
          AND f.following_id NOT IN (SELECT friend_id FROM my_friends)
    ),
    mutual_counts AS (
        SELECT 
            potential_friend,
            COUNT(DISTINCT mutual_friend) AS mutual_count
        FROM friends_of_friends
        GROUP BY potential_friend
    ),
    scored_recommendations AS (
        SELECT 
            mc.potential_friend,
            u.username,
            mc.mutual_count,
            (
                mc.mutual_count * 10.0 +
                COALESCE((SELECT COUNT(*) FROM Posts WHERE user_id = mc.potential_friend), 0) * 0.5 +
                COALESCE((SELECT COUNT(*) FROM Follows WHERE following_id = mc.potential_friend AND status_id = v_accepted_id), 0) * 0.1
            ) AS strength
        FROM mutual_counts mc
        INNER JOIN Users u ON u.user_id = mc.potential_friend
    )
    SELECT 
        potential_friend,
        username,
        mutual_count,
        ROUND(strength, 2) AS connection_strength
    FROM scored_recommendations
    ORDER BY strength DESC, mutual_count DESC
    LIMIT 50;
END;
$$ LANGUAGE plpgsql;

-- Function: Get social network distance
CREATE OR REPLACE FUNCTION get_social_network_distance(from_user_id INTEGER, to_user_id INTEGER)
RETURNS INTEGER AS $$
DECLARE
    shortest_distance INTEGER;
    v_accepted_id INT;
BEGIN
    SELECT status_id INTO v_accepted_id FROM FollowStatus WHERE status_name = 'accepted';

    WITH RECURSIVE social_path AS (
        SELECT 
            following_id AS user_node,
            1 AS distance,
            ARRAY[from_user_id, following_id] AS path_users
        FROM Follows
        WHERE follower_id = from_user_id
          AND status_id = v_accepted_id
        
        UNION ALL
        
        SELECT 
            f.following_id,
            sp.distance + 1,
            sp.path_users || f.following_id
        FROM social_path sp
        INNER JOIN Follows f ON f.follower_id = sp.user_node
        WHERE f.status_id = v_accepted_id
          AND sp.distance < 6
          AND NOT (f.following_id = ANY(sp.path_users))
    )
    SELECT MIN(distance) INTO shortest_distance
    FROM social_path
    WHERE user_node = to_user_id;
    
    RETURN shortest_distance;
END;
$$ LANGUAGE plpgsql;

-- Function: Compare query performance
CREATE OR REPLACE FUNCTION compare_query_performance()
RETURNS TABLE (
    approach VARCHAR,
    execution_time_ms NUMERIC,
    result_count INTEGER,
    notes TEXT
) AS $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    cte_time NUMERIC;
    subquery_time NUMERIC;
    temp_time NUMERIC;
    row_count INTEGER;
BEGIN
    -- Method 1: CTE
    start_time := clock_timestamp();
    
    WITH user_activity AS (
        SELECT 
            u.user_id,
            u.username,
            COUNT(DISTINCT p.post_id) AS post_count,
            COUNT(DISTINCT c.comment_id) AS comment_count
        FROM Users u
        LEFT JOIN Posts p ON p.user_id = u.user_id
        LEFT JOIN Comments c ON c.user_id = u.user_id
        GROUP BY u.user_id, u.username
    )
    SELECT COUNT(*) INTO row_count
    FROM user_activity
    WHERE post_count > 0 OR comment_count > 0;
    
    end_time := clock_timestamp();
    cte_time := EXTRACT(EPOCH FROM (end_time - start_time)) * 1000;
    
    RETURN QUERY SELECT 'CTE'::VARCHAR, ROUND(cte_time, 2), row_count, 'Most readable, good for complex queries'::TEXT;
    
    -- Method 2: Subquery
    start_time := clock_timestamp();
    
    SELECT COUNT(*) INTO row_count
    FROM (
        SELECT 
            u.user_id,
            u.username,
            COUNT(DISTINCT p.post_id) AS post_count,
            COUNT(DISTINCT c.comment_id) AS comment_count
        FROM Users u
        LEFT JOIN Posts p ON p.user_id = u.user_id
        LEFT JOIN Comments c ON c.user_id = u.user_id
        GROUP BY u.user_id, u.username
    ) user_activity
    WHERE post_count > 0 OR comment_count > 0;
    
    end_time := clock_timestamp();
    subquery_time := EXTRACT(EPOCH FROM (end_time - start_time)) * 1000;
    
    RETURN QUERY SELECT 'Subquery'::VARCHAR, ROUND(subquery_time, 2), row_count, 'Sometimes optimized better, less readable'::TEXT;
    
    -- Method 3: Temporary Table
    start_time := clock_timestamp();
    
    CREATE TEMP TABLE temp_user_activity AS
    SELECT 
        u.user_id,
        u.username,
        COUNT(DISTINCT p.post_id) AS post_count,
        COUNT(DISTINCT c.comment_id) AS comment_count
    FROM Users u
    LEFT JOIN Posts p ON p.user_id = u.user_id
    LEFT JOIN Comments c ON c.user_id = u.user_id
    GROUP BY u.user_id, u.username;
    
    SELECT COUNT(*) INTO row_count
    FROM temp_user_activity
    WHERE post_count > 0 OR comment_count > 0;
    
    DROP TABLE temp_user_activity;
    
    end_time := clock_timestamp();
    temp_time := EXTRACT(EPOCH FROM (end_time - start_time)) * 1000;
    
    RETURN QUERY SELECT 'Temp Table'::VARCHAR, ROUND(temp_time, 2), row_count, 'Best for reuse, overhead for creation'::TEXT;
    
    RETURN;
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

-- Community Member Count Trigger
CREATE TRIGGER update_member_count AFTER INSERT OR DELETE ON CommunityMembers FOR EACH ROW EXECUTE FUNCTION update_community_member_count();

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
-- WINDOW FUNCTION VIEWS
-- ============================================

-- View: User Post Sequence
CREATE OR REPLACE VIEW user_post_sequence AS
SELECT
    user_id,
    post_id,
    content,
    created_at,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at ASC) AS post_sequence_number,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at DESC) AS post_reverse_sequence
FROM Posts;

-- View: Daily Post Cumulative
CREATE OR REPLACE VIEW daily_post_cumulative AS
SELECT
    user_id,
    DATE(created_at) AS post_date,
    COUNT(*) OVER (PARTITION BY user_id) AS total_posts_by_user,
    COUNT(*) AS daily_post_count,
    SUM(COUNT(*)) OVER (PARTITION BY user_id ORDER BY DATE(created_at) ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_posts,
    ROUND(SUM(COUNT(*)) OVER (PARTITION BY user_id ORDER BY DATE(created_at) ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)::NUMERIC / (ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY DATE(created_at))), 2) AS average_posts_per_day
FROM Posts
GROUP BY user_id, DATE(created_at);

-- View: User Activity Ranking
CREATE OR REPLACE VIEW user_activity_ranking AS
SELECT
    user_id,
    username,
    total_posts,
    RANK() OVER (ORDER BY total_posts DESC) AS post_rank,
    DENSE_RANK() OVER (ORDER BY total_posts DESC) AS post_dense_rank,
    PERCENT_RANK() OVER (ORDER BY total_posts DESC) AS post_percentile,
    CUME_DIST() OVER (ORDER BY total_posts DESC) AS cumulative_distribution,
    NTILE(4) OVER (ORDER BY total_posts DESC) AS activity_quartile
FROM (
    SELECT
        u.user_id,
        u.username,
        COUNT(p.post_id) AS total_posts
    FROM Users u
    LEFT JOIN Posts p ON u.user_id = p.user_id
    GROUP BY u.user_id, u.username
) user_activity;

-- View: Post Comparison Analysis
CREATE OR REPLACE VIEW post_comparison_analysis AS
SELECT
    user_id,
    post_id,
    content,
    created_at,
    LAG(post_id, 1) OVER (PARTITION BY user_id ORDER BY created_at) AS previous_post_id,
    LAG(created_at, 1) OVER (PARTITION BY user_id ORDER BY created_at) AS previous_post_time,
    LEAD(post_id, 1) OVER (PARTITION BY user_id ORDER BY created_at) AS next_post_id,
    LEAD(created_at, 1) OVER (PARTITION BY user_id ORDER BY created_at) AS next_post_time,
    EXTRACT(HOUR FROM created_at - LAG(created_at, 1) OVER (PARTITION BY user_id ORDER BY created_at)) AS hours_since_previous,
    EXTRACT(HOUR FROM LEAD(created_at, 1) OVER (PARTITION BY user_id ORDER BY created_at) - created_at) AS hours_until_next,
    LAG(post_id, 2) OVER (PARTITION BY user_id ORDER BY created_at) AS post_2_back,
    LEAD(post_id, 2) OVER (PARTITION BY user_id ORDER BY created_at) AS post_2_ahead
FROM Posts;

-- View: Posting Consistency Metrics
CREATE OR REPLACE VIEW posting_consistency_metrics AS
SELECT
    user_id,
    username,
    post_count,
    ROUND((EXTRACT(EPOCH FROM (last_post - first_post)) / 3600 / NULLIF(post_count - 1, 0))::numeric, 2) AS avg_hours_between_posts,
    ROUND(STDDEV(hours_gap)::NUMERIC, 2) AS posting_consistency_score,
    ROUND(post_count::NUMERIC / NULLIF(EXTRACT(DAY FROM (last_post - first_post)) + 1, 0), 2) AS posts_per_day,
    RANK() OVER (ORDER BY STDDEV(hours_gap) ASC NULLS LAST) AS consistency_rank
FROM (
    SELECT
        u.user_id,
        u.username,
        COUNT(p.post_id) OVER (PARTITION BY u.user_id) AS post_count,
        MIN(p.created_at) OVER (PARTITION BY u.user_id) AS first_post,
        MAX(p.created_at) OVER (PARTITION BY u.user_id) AS last_post,
        EXTRACT(HOUR FROM p.created_at - LAG(p.created_at) OVER (PARTITION BY u.user_id ORDER BY p.created_at)) AS hours_gap
    FROM Users u
    LEFT JOIN Posts p ON u.user_id = p.user_id
) consistency_data
WHERE post_count > 1
GROUP BY user_id, username, post_count, first_post, last_post;

-- View: Post Engagement Trends
CREATE OR REPLACE VIEW post_engagement_trends AS
SELECT
    user_id,
    post_id,
    created_at,
    like_count,
    LAG(like_count, 1, 0) OVER (PARTITION BY user_id ORDER BY created_at) AS previous_like_count,
    like_count - LAG(like_count, 1, 0) OVER (PARTITION BY user_id ORDER BY created_at) AS engagement_change,
    ROUND(AVG(like_count) OVER (PARTITION BY user_id ORDER BY created_at ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS moving_avg_likes_3post,
    ROUND((PERCENT_RANK() OVER (PARTITION BY user_id ORDER BY like_count) * 100)::numeric, 2) AS like_percentile_by_user
FROM (
    SELECT
        p.user_id,
        p.post_id,
        p.created_at,
        COUNT(pl.user_id) AS like_count
    FROM Posts p
    LEFT JOIN PostLikes pl ON p.post_id = pl.post_id
    GROUP BY p.post_id, p.user_id, p.created_at
) post_engagement;

-- ============================================
-- CTE VIEWS
-- ============================================

-- View: Comment threads with metrics
CREATE OR REPLACE VIEW comment_thread_with_metrics AS
WITH RECURSIVE comment_metrics AS (
    SELECT 
        c.comment_id,
        c.post_id,
        c.parent_comment_id,
        c.user_id,
        c.content,
        c.created_at,
        0 AS depth,
        1 AS reply_count,
        ARRAY[c.comment_id] AS path
    FROM Comments c
    WHERE c.parent_comment_id IS NULL
    
    UNION ALL
    
    SELECT 
        c.comment_id,
        c.post_id,
        c.parent_comment_id,
        c.user_id,
        c.content,
        c.created_at,
        cm.depth + 1,
        cm.reply_count + 1,
        cm.path || c.comment_id
    FROM Comments c
    INNER JOIN comment_metrics cm ON c.parent_comment_id = cm.comment_id
    WHERE cm.depth < 10
)
SELECT 
    cm.comment_id,
    cm.post_id,
    cm.parent_comment_id,
    u.username,
    cm.content,
    cm.created_at,
    cm.depth,
    COUNT(*) OVER (PARTITION BY cm.path[1]) AS thread_size,
    MAX(cm.depth) OVER (PARTITION BY cm.path[1]) AS max_thread_depth
FROM comment_metrics cm
INNER JOIN Users u ON cm.user_id = u.user_id;

-- View: Advanced friend recommendations
CREATE OR REPLACE VIEW advanced_friend_recommendations AS
WITH user_friends AS (
    SELECT 
        f.follower_id AS user_id,
        f.following_id AS friend_id
    FROM Follows f
    WHERE f.status_id = (SELECT status_id FROM FollowStatus WHERE status_name = 'accepted')
),
friend_suggestions AS (
    SELECT DISTINCT
        uf1.user_id,
        uf2.friend_id AS suggested_friend,
        COUNT(DISTINCT uf1.friend_id) AS mutual_count
    FROM user_friends uf1
    INNER JOIN user_friends uf2 ON uf1.friend_id = uf2.user_id
    WHERE uf2.friend_id != uf1.user_id
      AND NOT EXISTS (
          SELECT 1 FROM user_friends uf3
          WHERE uf3.user_id = uf1.user_id
            AND uf3.friend_id = uf2.friend_id
      )
    GROUP BY uf1.user_id, uf2.friend_id
)
SELECT 
    fs.user_id,
    u.username AS suggested_username,
    fs.mutual_count,
    COALESCE((SELECT COUNT(*) FROM Posts WHERE user_id = fs.suggested_friend), 0) AS post_count,
    COALESCE((SELECT COUNT(*) FROM Follows WHERE following_id = fs.suggested_friend AND status_id = (SELECT status_id FROM FollowStatus WHERE status_name = 'accepted')), 0) AS follower_count,
    (
        fs.mutual_count * 10.0 +
        COALESCE((SELECT COUNT(*) FROM Posts WHERE user_id = fs.suggested_friend), 0) * 0.5 +
        COALESCE((SELECT COUNT(*) FROM Follows WHERE following_id = fs.suggested_friend AND status_id = (SELECT status_id FROM FollowStatus WHERE status_name = 'accepted')), 0) * 0.1
    ) AS recommendation_score
FROM friend_suggestions fs
INNER JOIN Users u ON u.user_id = fs.suggested_friend
ORDER BY fs.user_id, recommendation_score DESC;

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

-- Message Indexes
CREATE INDEX idx_messages_sender_id ON Messages(sender_id);
CREATE INDEX idx_messages_receiver_id ON Messages(receiver_id);
CREATE INDEX idx_messages_unread ON Messages(receiver_id) WHERE is_read = FALSE;

-- GIN Indexes for Search
CREATE INDEX idx_posts_search_vector ON Posts USING GIN(search_vector);
CREATE INDEX idx_users_search_vector ON Users USING GIN(search_vector);

-- Window Function Indexes
CREATE INDEX IF NOT EXISTS idx_posts_user_created ON Posts(user_id, created_at);
-- idx_post_likes_post_id already exists as idx_postlikes_post_id
CREATE INDEX IF NOT EXISTS idx_postlikes_user_id ON PostLikes(user_id);

-- CTE Indexes
CREATE INDEX IF NOT EXISTS idx_comments_parent_post ON Comments(parent_comment_id, post_id);
CREATE INDEX IF NOT EXISTS idx_follows_status ON Follows(status_id, following_id);


