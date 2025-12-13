-- ============================================================================
-- CTE Module Setup Script
-- ============================================================================
-- Purpose: One-command setup for all CTE functions, views, and examples
-- Run this file to install the complete CTE module
-- PostgreSQL Version: 12+
-- ============================================================================

\echo '===================================================================='
\echo 'CTE Module Installation Script'
\echo '===================================================================='
\echo ''

\echo 'Starting CTE module installation...'
\echo ''

-- ============================================================================
-- STEP 1: Create Recursive CTE Functions
-- ============================================================================

\echo '===================================================================='
\echo 'STEP 1: Creating Recursive CTE Functions'
\echo '===================================================================='
\echo ''

-- Function: Get comment thread for a post
\echo 'Creating function: get_comment_thread()...'

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
        -- Base case: Top-level comments (no parent)
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
        
        -- Recursive case: Child comments
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
        WHERE ct.depth < 10  -- Prevent infinite recursion
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

\echo '✓ Function get_comment_thread() created'
\echo ''

-- Function: Get comment ancestors
\echo 'Creating function: get_comment_ancestors()...'

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
        -- Base: Target comment
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
        
        -- Recursive: Parent comments
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

\echo '✓ Function get_comment_ancestors() created'
\echo ''

-- ============================================================================
-- STEP 2: Create Friend-of-Friend Functions
-- ============================================================================

\echo '===================================================================='
\echo 'STEP 2: Creating Friend-of-Friend Functions'
\echo '===================================================================='
\echo ''

-- Function: Get friend-of-friend recommendations
\echo 'Creating function: get_friend_of_friend_recommendations()...'

CREATE OR REPLACE FUNCTION get_friend_of_friend_recommendations(target_user_id INTEGER)
RETURNS TABLE (
    recommended_user INTEGER,
    username VARCHAR,
    mutual_friends INTEGER,
    connection_strength NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH 
    -- Step 1: Get direct friends
    my_friends AS (
        SELECT following_id AS friend_id
        FROM Follows
        WHERE follower_id = target_user_id
          AND status_id = 1
    ),
    -- Step 2: Get friends of friends
    friends_of_friends AS (
        SELECT DISTINCT
            f.following_id AS potential_friend,
            mf.friend_id AS mutual_friend
        FROM my_friends mf
        INNER JOIN Follows f ON f.follower_id = mf.friend_id
        WHERE f.status_id = 1
          AND f.following_id != target_user_id
          AND f.following_id NOT IN (SELECT friend_id FROM my_friends)
    ),
    -- Step 3: Calculate mutual friend count
    mutual_counts AS (
        SELECT 
            potential_friend,
            COUNT(DISTINCT mutual_friend) AS mutual_count
        FROM friends_of_friends
        GROUP BY potential_friend
    ),
    -- Step 4: Calculate connection strength
    scored_recommendations AS (
        SELECT 
            mc.potential_friend,
            u.username,
            mc.mutual_count,
            (
                mc.mutual_count * 10.0 +
                COALESCE((SELECT COUNT(*) FROM Posts WHERE user_id = mc.potential_friend), 0) * 0.5 +
                COALESCE((SELECT COUNT(*) FROM Follows WHERE following_id = mc.potential_friend AND status_id = 1), 0) * 0.1
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

\echo '✓ Function get_friend_of_friend_recommendations() created'
\echo ''

-- Function: Get social network distance
\echo 'Creating function: get_social_network_distance()...'

CREATE OR REPLACE FUNCTION get_social_network_distance(from_user_id INTEGER, to_user_id INTEGER)
RETURNS INTEGER AS $$
DECLARE
    shortest_distance INTEGER;
BEGIN
    WITH RECURSIVE social_path AS (
        -- Base: Direct connections
        SELECT 
            following_id AS user_node,
            1 AS distance,
            ARRAY[from_user_id, following_id] AS path_users
        FROM Follows
        WHERE follower_id = from_user_id
          AND status_id = 1
        
        UNION ALL
        
        -- Recursive: Extended connections
        SELECT 
            f.following_id,
            sp.distance + 1,
            sp.path_users || f.following_id
        FROM social_path sp
        INNER JOIN Follows f ON f.follower_id = sp.user_node
        WHERE f.status_id = 1
          AND sp.distance < 6  -- 6 degrees of separation
          AND NOT (f.following_id = ANY(sp.path_users))  -- Avoid cycles
    )
    SELECT MIN(distance) INTO shortest_distance
    FROM social_path
    WHERE user_node = to_user_id;
    
    RETURN shortest_distance;
END;
$$ LANGUAGE plpgsql;

\echo '✓ Function get_social_network_distance() created'
\echo ''

-- ============================================================================
-- STEP 3: Create Performance Comparison Function
-- ============================================================================

\echo '===================================================================='
\echo 'STEP 3: Creating Performance Comparison Function'
\echo '===================================================================='
\echo ''

\echo 'Creating function: compare_query_performance()...'

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

\echo '✓ Function compare_query_performance() created'
\echo ''

-- ============================================================================
-- STEP 4: Create Views
-- ============================================================================

\echo '===================================================================='
\echo 'STEP 4: Creating CTE Views'
\echo '===================================================================='
\echo ''

-- View: Comment threads with metrics
\echo 'Creating view: comment_thread_with_metrics...'

CREATE OR REPLACE VIEW comment_thread_with_metrics AS
WITH RECURSIVE comment_metrics AS (
    -- Base case: Top-level comments
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
    
    -- Recursive case: Child comments
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

\echo '✓ View comment_thread_with_metrics created'
\echo ''

-- View: Advanced friend recommendations
\echo 'Creating view: advanced_friend_recommendations...'

CREATE OR REPLACE VIEW advanced_friend_recommendations AS
WITH user_friends AS (
    SELECT 
        f.follower_id AS user_id,
        f.following_id AS friend_id
    FROM Follows f
    WHERE f.status_id = 1
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
    COALESCE((SELECT COUNT(*) FROM Follows WHERE following_id = fs.suggested_friend AND status_id = 1), 0) AS follower_count,
    (
        fs.mutual_count * 10.0 +
        COALESCE((SELECT COUNT(*) FROM Posts WHERE user_id = fs.suggested_friend), 0) * 0.5 +
        COALESCE((SELECT COUNT(*) FROM Follows WHERE following_id = fs.suggested_friend AND status_id = 1), 0) * 0.1
    ) AS recommendation_score
FROM friend_suggestions fs
INNER JOIN Users u ON u.user_id = fs.suggested_friend
ORDER BY fs.user_id, recommendation_score DESC;

\echo '✓ View advanced_friend_recommendations created'
\echo ''

-- ============================================================================
-- STEP 5: Create Indexes (if needed)
-- ============================================================================

\echo '===================================================================='
\echo 'STEP 5: Creating Supporting Indexes'
\echo '===================================================================='
\echo ''

\echo 'Checking for existing indexes...'

-- Index for comment traversal
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE indexname = 'idx_comments_parent_post'
    ) THEN
        CREATE INDEX idx_comments_parent_post ON Comments(parent_comment_id, post_id);
        RAISE NOTICE '✓ Index idx_comments_parent_post created';
    ELSE
        RAISE NOTICE '✓ Index idx_comments_parent_post already exists';
    END IF;
END $$;

-- Index for follow relationships
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE indexname = 'idx_follows_relationships'
    ) THEN
        CREATE INDEX idx_follows_relationships ON Follows(follower_id, following_id, status_id);
        RAISE NOTICE '✓ Index idx_follows_relationships created';
    ELSE
        RAISE NOTICE '✓ Index idx_follows_relationships already exists';
    END IF;
END $$;

-- Index for follow status
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE indexname = 'idx_follows_status'
    ) THEN
        CREATE INDEX idx_follows_status ON Follows(status_id, following_id);
        RAISE NOTICE '✓ Index idx_follows_status created';
    ELSE
        RAISE NOTICE '✓ Index idx_follows_status already exists';
    END IF;
END $$;

\echo ''

-- ============================================================================
-- INSTALLATION COMPLETE
-- ============================================================================

\echo '===================================================================='
\echo 'CTE Module Installation Complete!'
\echo '===================================================================='
\echo ''
\echo 'Successfully installed:'
\echo '  - 4 Functions: get_comment_thread(), get_comment_ancestors(),'
\echo '                get_friend_of_friend_recommendations(), get_social_network_distance()'
\echo '  - 1 Utility: compare_query_performance()'
\echo '  - 2 Views: comment_thread_with_metrics, advanced_friend_recommendations'
\echo '  - 3 Indexes: For optimized recursive queries'
\echo ''
\echo 'Next steps:'
\echo '  1. Run 03_testing_validation.sql to verify installation'
\echo '  2. Review CTE_README.md for usage documentation'
\echo '  3. Explore 02_practical_examples.sql for examples'
\echo ''
\echo 'Quick test:'
\echo '  SELECT * FROM comment_thread_with_metrics LIMIT 5;'
\echo '  SELECT * FROM advanced_friend_recommendations LIMIT 10;'
\echo ''
\echo '===================================================================='
