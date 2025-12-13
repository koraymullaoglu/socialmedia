-- ============================================================================
-- PostgreSQL CTEs (Common Table Expressions) - Recursive & Non-Recursive
-- ============================================================================
-- This module implements advanced CTE patterns including:
-- - Recursive CTEs for nested comment threads
-- - Friend-of-friend recommendations (graph traversal)
-- - Performance comparison: CTE vs Subquery vs Temporary Tables
-- ============================================================================

-- ============================================================================
-- 1. RECURSIVE CTE FOR NESTED COMMENT THREADS
-- ============================================================================
-- Build hierarchical comment trees with unlimited nesting depth

-- ============================================================================
-- 1.1 Basic Recursive CTE - Comment Thread Tree
-- ============================================================================

CREATE OR REPLACE FUNCTION get_comment_thread(root_post_id INT)
RETURNS TABLE (
    comment_id INT,
    parent_comment_id INT,
    user_id INT,
    content TEXT,
    created_at TIMESTAMP,
    depth INT,
    path TEXT,
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
            c.content,
            c.created_at,
            0 AS depth,
            c.comment_id::TEXT AS path,
            LPAD(ROW_NUMBER() OVER (ORDER BY c.created_at)::TEXT, 5, '0') AS thread_position
        FROM Comments c
        WHERE c.post_id = root_post_id
          AND c.parent_comment_id IS NULL
        
        UNION ALL
        
        -- Recursive case: Nested replies
        SELECT 
            c.comment_id,
            c.parent_comment_id,
            c.user_id,
            c.content,
            c.created_at,
            ct.depth + 1,
            ct.path || '->' || c.comment_id::TEXT,
            ct.thread_position || '.' || LPAD(ROW_NUMBER() OVER (
                PARTITION BY c.parent_comment_id 
                ORDER BY c.created_at
            )::TEXT, 5, '0')
        FROM Comments c
        INNER JOIN comment_tree ct ON c.parent_comment_id = ct.comment_id
        WHERE ct.depth < 10  -- Prevent infinite recursion
    )
    SELECT * FROM comment_tree
    ORDER BY thread_position;
END;
$$ LANGUAGE plpgsql;

-- Query: Display formatted comment thread
SELECT 
    REPEAT('  ', depth) || '└─ ' || u.username AS thread_structure,
    ct.content,
    ct.depth,
    ct.created_at,
    ct.path AS comment_path
FROM get_comment_thread(1) ct
INNER JOIN Users u ON ct.user_id = u.user_id;


-- ============================================================================
-- 1.2 Enhanced Recursive CTE with Metrics
-- ============================================================================

CREATE OR REPLACE VIEW comment_thread_with_metrics AS
WITH RECURSIVE comment_hierarchy AS (
    -- Root level comments
    SELECT 
        c.comment_id,
        c.post_id,
        c.parent_comment_id,
        c.user_id,
        c.content,
        c.created_at,
        0 AS depth,
        ARRAY[c.comment_id] AS path_array,
        c.comment_id::TEXT AS path_string,
        1 AS total_replies,
        0 AS direct_replies
    FROM Comments c
    WHERE c.parent_comment_id IS NULL
    
    UNION ALL
    
    -- Nested comments
    SELECT 
        c.comment_id,
        c.post_id,
        c.parent_comment_id,
        c.user_id,
        c.content,
        c.created_at,
        ch.depth + 1,
        ch.path_array || c.comment_id,
        ch.path_string || ' -> ' || c.comment_id::TEXT,
        ch.total_replies + 1,
        CASE 
            WHEN c.parent_comment_id = ch.comment_id THEN ch.direct_replies + 1
            ELSE ch.direct_replies
        END
    FROM Comments c
    INNER JOIN comment_hierarchy ch ON c.parent_comment_id = ch.comment_id
    WHERE ch.depth < 20
)
SELECT 
    ch.comment_id,
    ch.post_id,
    ch.parent_comment_id,
    u.username,
    ch.content,
    ch.created_at,
    ch.depth,
    ch.path_string,
    ch.total_replies,
    ch.direct_replies,
    -- Calculate metrics
    (SELECT COUNT(*) FROM Comments WHERE parent_comment_id = ch.comment_id) AS immediate_children,
    CASE 
        WHEN ch.depth = 0 THEN 'Root'
        WHEN ch.depth = 1 THEN 'Direct Reply'
        WHEN ch.depth = 2 THEN 'Nested Reply'
        ELSE 'Deep Reply (Level ' || ch.depth || ')'
    END AS comment_level
FROM comment_hierarchy ch
INNER JOIN Users u ON ch.user_id = u.user_id;

-- Query: Get thread statistics
SELECT 
    post_id,
    MAX(depth) AS max_thread_depth,
    COUNT(*) AS total_comments,
    COUNT(CASE WHEN depth = 0 THEN 1 END) AS root_comments,
    ROUND(AVG(depth), 2) AS avg_depth
FROM comment_thread_with_metrics
GROUP BY post_id;


-- ============================================================================
-- 1.3 Recursive CTE - Find All Comment Ancestors
-- ============================================================================

CREATE OR REPLACE FUNCTION get_comment_ancestors(target_comment_id INT)
RETURNS TABLE (
    comment_id INT,
    parent_comment_id INT,
    username VARCHAR(50),
    content TEXT,
    created_at TIMESTAMP,
    level_from_target INT
) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE ancestor_chain AS (
        -- Start with target comment
        SELECT 
            c.comment_id,
            c.parent_comment_id,
            c.user_id,
            c.content,
            c.created_at,
            0 AS level_from_target
        FROM Comments c
        WHERE c.comment_id = target_comment_id
        
        UNION ALL
        
        -- Walk up the tree
        SELECT 
            c.comment_id,
            c.parent_comment_id,
            c.user_id,
            c.content,
            c.created_at,
            ac.level_from_target + 1
        FROM Comments c
        INNER JOIN ancestor_chain ac ON c.comment_id = ac.parent_comment_id
    )
    SELECT 
        ac.comment_id,
        ac.parent_comment_id,
        u.username,
        ac.content,
        ac.created_at,
        ac.level_from_target
    FROM ancestor_chain ac
    INNER JOIN Users u ON ac.user_id = u.user_id
    ORDER BY ac.level_from_target DESC;
END;
$$ LANGUAGE plpgsql;

-- Query: Show conversation context
SELECT 
    level_from_target,
    REPEAT('  ', level_from_target) || username AS conversation_thread,
    content,
    created_at
FROM get_comment_ancestors(42);


-- ============================================================================
-- 2. FRIEND-OF-FRIEND RECOMMENDATIONS (2ND DEGREE CONNECTIONS)
-- ============================================================================
-- Graph traversal to find potential connections through mutual friends

-- ============================================================================
-- 2.1 Basic Friend-of-Friend (2-hop traversal)
-- ============================================================================

CREATE OR REPLACE FUNCTION get_friend_of_friend_recommendations(target_user_id INT)
RETURNS TABLE (
    recommended_user_id INT,
    recommended_username VARCHAR(50),
    mutual_friends_count BIGINT,
    mutual_friends TEXT,
    connection_strength NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH 
    -- Direct friends (1st degree)
    direct_friends AS (
        SELECT following_id AS friend_id
        FROM Follows
        WHERE follower_id = target_user_id
          AND status_id = 1  -- Assuming 1 = accepted
    ),
    -- Friends of friends (2nd degree)
    friends_of_friends AS (
        SELECT DISTINCT 
            f.following_id AS potential_friend_id,
            df.friend_id AS mutual_friend_id
        FROM direct_friends df
        INNER JOIN Follows f ON f.follower_id = df.friend_id
        WHERE f.following_id != target_user_id  -- Not the user themselves
          AND f.status_id = 1
          AND f.following_id NOT IN (SELECT friend_id FROM direct_friends)  -- Not already friends
    ),
    -- Aggregate mutual friends
    recommendations AS (
        SELECT 
            fof.potential_friend_id,
            COUNT(DISTINCT fof.mutual_friend_id) AS mutual_count,
            ARRAY_AGG(DISTINCT u.username ORDER BY u.username) AS mutual_names
        FROM friends_of_friends fof
        INNER JOIN Users u ON u.user_id = fof.mutual_friend_id
        GROUP BY fof.potential_friend_id
        HAVING COUNT(DISTINCT fof.mutual_friend_id) >= 1
    )
    SELECT 
        r.potential_friend_id,
        u.username,
        r.mutual_count,
        ARRAY_TO_STRING(r.mutual_names, ', '),
        -- Connection strength: more mutual friends = stronger connection
        ROUND((r.mutual_count::NUMERIC / (SELECT COUNT(*) FROM direct_friends)) * 100, 2) AS connection_strength
    FROM recommendations r
    INNER JOIN Users u ON u.user_id = r.potential_friend_id
    ORDER BY r.mutual_count DESC, u.username;
END;
$$ LANGUAGE plpgsql;

-- Query: Get top friend recommendations
SELECT 
    recommended_username,
    mutual_friends_count || ' mutual friend(s)' AS mutual_friends,
    mutual_friends AS friend_names,
    connection_strength || '%' AS strength
FROM get_friend_of_friend_recommendations(1)
LIMIT 10;


-- ============================================================================
-- 2.2 Recursive CTE - Multi-Degree Social Network Traversal
-- ============================================================================

CREATE OR REPLACE FUNCTION get_social_network_distance(
    from_user_id INT, 
    to_user_id INT,
    max_depth INT DEFAULT 6
)
RETURNS TABLE (
    distance INT,
    path_users INT[],
    path_usernames TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE social_path AS (
        -- Base case: Direct connections
        SELECT 
            f.following_id AS current_user,
            1 AS distance,
            ARRAY[from_user_id, f.following_id] AS path_users
        FROM Follows f
        WHERE f.follower_id = from_user_id
          AND f.status_id = 1
        
        UNION ALL
        
        -- Recursive case: Extend the path
        SELECT 
            f.following_id,
            sp.distance + 1,
            sp.path_users || f.following_id
        FROM social_path sp
        INNER JOIN Follows f ON f.follower_id = sp.current_user
        WHERE f.status_id = 1
          AND sp.distance < max_depth
          AND NOT (f.following_id = ANY(sp.path_users))  -- Avoid cycles
          AND sp.current_user != to_user_id  -- Stop if we found the target
    )
    SELECT 
        sp.distance,
        sp.path_users,
        (
            SELECT STRING_AGG(u.username, ' -> ' ORDER BY idx)
            FROM UNNEST(sp.path_users) WITH ORDINALITY AS t(user_id, idx)
            INNER JOIN Users u ON u.user_id = t.user_id
        ) AS path_usernames
    FROM social_path sp
    WHERE sp.current_user = to_user_id
    ORDER BY sp.distance
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Query: Find shortest path between two users
SELECT 
    CASE 
        WHEN distance IS NULL THEN 'Not connected'
        WHEN distance = 1 THEN 'Direct connection'
        ELSE distance || ' degrees of separation'
    END AS connection_type,
    path_usernames AS connection_path
FROM get_social_network_distance(1, 10, 6);


-- ============================================================================
-- 2.3 Advanced Friend Recommendations with Scoring
-- ============================================================================

CREATE OR REPLACE VIEW advanced_friend_recommendations AS
WITH 
-- Calculate user's direct network
user_network AS (
    SELECT 
        follower_id AS user_id,
        following_id AS friend_id
    FROM Follows
    WHERE status_id = 1
),
-- Friends of friends with detailed metrics
fof_metrics AS (
    SELECT 
        un1.user_id,
        un2.friend_id AS recommended_user,
        COUNT(DISTINCT un1.friend_id) AS mutual_friends,
        ARRAY_AGG(DISTINCT un1.friend_id) AS mutual_friend_ids
    FROM user_network un1
    INNER JOIN user_network un2 ON un1.friend_id = un2.user_id
    WHERE un2.friend_id != un1.user_id  -- Not self
      AND un2.friend_id NOT IN (
          SELECT friend_id FROM user_network WHERE user_id = un1.user_id
      )  -- Not already friends
    GROUP BY un1.user_id, un2.friend_id
),
-- Calculate additional scoring factors
recommendation_scores AS (
    SELECT 
        fm.user_id,
        fm.recommended_user,
        u.username AS recommended_username,
        fm.mutual_friends,
        -- Count posts by recommended user
        (SELECT COUNT(*) FROM Posts WHERE user_id = fm.recommended_user) AS post_count,
        -- Count followers of recommended user
        (SELECT COUNT(*) FROM Follows WHERE following_id = fm.recommended_user AND status_id = 1) AS follower_count,
        -- Calculate composite score
        (
            fm.mutual_friends * 10 +  -- Weight mutual friends heavily
            LEAST((SELECT COUNT(*) FROM Posts WHERE user_id = fm.recommended_user), 10) * 2 +  -- Activity bonus
            LEAST((SELECT COUNT(*) FROM Follows WHERE following_id = fm.recommended_user AND status_id = 1), 50) * 1  -- Popularity bonus
        ) AS recommendation_score
    FROM fof_metrics fm
    INNER JOIN Users u ON u.user_id = fm.recommended_user
)
SELECT 
    rs.user_id,
    rs.recommended_user,
    rs.recommended_username,
    rs.mutual_friends,
    (
        SELECT STRING_AGG(u.username, ', ')
        FROM user_network un
        INNER JOIN Users u ON u.user_id = un.friend_id
        WHERE un.user_id = rs.user_id
          AND un.friend_id IN (
              SELECT friend_id FROM user_network WHERE user_id = rs.recommended_user
          )
    ) AS mutual_friend_names,
    rs.post_count,
    rs.follower_count,
    rs.recommendation_score,
    NTILE(10) OVER (PARTITION BY rs.user_id ORDER BY rs.recommendation_score DESC) AS score_percentile
FROM recommendation_scores rs;

-- Query: Get personalized recommendations
SELECT 
    recommended_username,
    mutual_friends || ' mutual friends' AS connection,
    mutual_friend_names,
    recommendation_score AS score,
    CASE 
        WHEN score_percentile = 1 THEN '⭐⭐⭐ Highly Recommended'
        WHEN score_percentile <= 3 THEN '⭐⭐ Recommended'
        ELSE '⭐ Suggested'
    END AS recommendation_level
FROM advanced_friend_recommendations
WHERE user_id = 1
ORDER BY recommendation_score DESC
LIMIT 20;


-- ============================================================================
-- 3. PERFORMANCE COMPARISON: CTE vs SUBQUERY vs TEMPORARY TABLE
-- ============================================================================

-- ============================================================================
-- 3.1 Test Scenario: Find Active Users with Engagement Metrics
-- ============================================================================

-- Method 1: Using CTE (Recommended for readability)
EXPLAIN ANALYZE
WITH user_stats AS (
    SELECT 
        u.user_id,
        u.username,
        COUNT(DISTINCT p.post_id) AS post_count,
        COUNT(DISTINCT c.comment_id) AS comment_count,
        COUNT(DISTINCT pl.like_id) AS likes_received
    FROM Users u
    LEFT JOIN Posts p ON u.user_id = p.user_id
    LEFT JOIN Comments c ON u.user_id = c.user_id
    LEFT JOIN Post_Likes pl ON p.post_id = pl.post_id
    WHERE u.created_at >= NOW() - INTERVAL '30 days'
    GROUP BY u.user_id, u.username
),
active_users AS (
    SELECT 
        user_id,
        username,
        post_count,
        comment_count,
        likes_received,
        post_count + comment_count + (likes_received / 10) AS engagement_score
    FROM user_stats
    WHERE post_count > 0 OR comment_count > 0
)
SELECT * FROM active_users
WHERE engagement_score > 10
ORDER BY engagement_score DESC;


-- Method 2: Using Subqueries (Less readable, potentially slower)
EXPLAIN ANALYZE
SELECT 
    u.user_id,
    u.username,
    post_stats.post_count,
    comment_stats.comment_count,
    like_stats.likes_received,
    post_stats.post_count + comment_stats.comment_count + (like_stats.likes_received / 10) AS engagement_score
FROM Users u
LEFT JOIN (
    SELECT user_id, COUNT(*) AS post_count
    FROM Posts
    GROUP BY user_id
) post_stats ON u.user_id = post_stats.user_id
LEFT JOIN (
    SELECT user_id, COUNT(*) AS comment_count
    FROM Comments
    GROUP BY user_id
) comment_stats ON u.user_id = comment_stats.user_id
LEFT JOIN (
    SELECT p.user_id, COUNT(pl.like_id) AS likes_received
    FROM Posts p
    LEFT JOIN Post_Likes pl ON p.post_id = pl.post_id
    GROUP BY p.user_id
) like_stats ON u.user_id = like_stats.user_id
WHERE u.created_at >= NOW() - INTERVAL '30 days'
  AND (post_stats.post_count > 0 OR comment_stats.comment_count > 0)
  AND (post_stats.post_count + comment_stats.comment_count + (like_stats.likes_received / 10)) > 10
ORDER BY engagement_score DESC;


-- Method 3: Using Temporary Table (Best for repeated access)
EXPLAIN ANALYZE
CREATE TEMPORARY TABLE temp_user_stats AS
SELECT 
    u.user_id,
    u.username,
    COUNT(DISTINCT p.post_id) AS post_count,
    COUNT(DISTINCT c.comment_id) AS comment_count,
    COUNT(DISTINCT pl.like_id) AS likes_received
FROM Users u
LEFT JOIN Posts p ON u.user_id = p.user_id
LEFT JOIN Comments c ON u.user_id = c.user_id
LEFT JOIN Post_Likes pl ON p.post_id = pl.post_id
WHERE u.created_at >= NOW() - INTERVAL '30 days'
GROUP BY u.user_id, u.username;

CREATE INDEX idx_temp_user_stats_user_id ON temp_user_stats(user_id);

SELECT 
    user_id,
    username,
    post_count,
    comment_count,
    likes_received,
    post_count + comment_count + (likes_received / 10) AS engagement_score
FROM temp_user_stats
WHERE post_count > 0 OR comment_count > 0
  AND (post_count + comment_count + (likes_received / 10)) > 10
ORDER BY engagement_score DESC;

DROP TABLE temp_user_stats;


-- ============================================================================
-- 3.2 Performance Comparison Function
-- ============================================================================

CREATE OR REPLACE FUNCTION compare_query_performance()
RETURNS TABLE (
    method TEXT,
    execution_time_ms NUMERIC,
    rows_returned BIGINT,
    relative_performance TEXT
) AS $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    cte_time NUMERIC;
    subquery_time NUMERIC;
    temp_table_time NUMERIC;
    row_count BIGINT;
BEGIN
    -- Test 1: CTE Method
    start_time := clock_timestamp();
    
    WITH user_stats AS (
        SELECT 
            u.user_id,
            COUNT(DISTINCT p.post_id) AS post_count,
            COUNT(DISTINCT c.comment_id) AS comment_count
        FROM Users u
        LEFT JOIN Posts p ON u.user_id = p.user_id
        LEFT JOIN Comments c ON u.user_id = c.user_id
        GROUP BY u.user_id
    )
    SELECT COUNT(*) INTO row_count FROM user_stats WHERE post_count > 0;
    
    end_time := clock_timestamp();
    cte_time := EXTRACT(MILLISECOND FROM (end_time - start_time));
    
    method := 'CTE (Common Table Expression)';
    execution_time_ms := cte_time;
    rows_returned := row_count;
    relative_performance := 'Baseline';
    RETURN NEXT;
    
    -- Test 2: Subquery Method
    start_time := clock_timestamp();
    
    SELECT COUNT(*) INTO row_count
    FROM Users u
    LEFT JOIN (
        SELECT user_id, COUNT(*) AS post_count
        FROM Posts GROUP BY user_id
    ) ps ON u.user_id = ps.user_id
    LEFT JOIN (
        SELECT user_id, COUNT(*) AS comment_count
        FROM Comments GROUP BY user_id
    ) cs ON u.user_id = cs.user_id
    WHERE ps.post_count > 0;
    
    end_time := clock_timestamp();
    subquery_time := EXTRACT(MILLISECOND FROM (end_time - start_time));
    
    method := 'Subquery';
    execution_time_ms := subquery_time;
    rows_returned := row_count;
    relative_performance := ROUND((subquery_time / cte_time) * 100, 2) || '% of CTE';
    RETURN NEXT;
    
    -- Test 3: Temporary Table Method
    start_time := clock_timestamp();
    
    CREATE TEMPORARY TABLE perf_test_temp AS
    SELECT 
        u.user_id,
        COUNT(DISTINCT p.post_id) AS post_count,
        COUNT(DISTINCT c.comment_id) AS comment_count
    FROM Users u
    LEFT JOIN Posts p ON u.user_id = p.user_id
    LEFT JOIN Comments c ON u.user_id = c.user_id
    GROUP BY u.user_id;
    
    SELECT COUNT(*) INTO row_count FROM perf_test_temp WHERE post_count > 0;
    DROP TABLE perf_test_temp;
    
    end_time := clock_timestamp();
    temp_table_time := EXTRACT(MILLISECOND FROM (end_time - start_time));
    
    method := 'Temporary Table';
    execution_time_ms := temp_table_time;
    rows_returned := row_count;
    relative_performance := ROUND((temp_table_time / cte_time) * 100, 2) || '% of CTE';
    RETURN NEXT;
    
END;
$$ LANGUAGE plpgsql;

-- Run performance comparison
SELECT * FROM compare_query_performance();


-- ============================================================================
-- 3.3 CTE vs Subquery - Practical Examples
-- ============================================================================

-- Example 1: CTE Version (Readable, Maintainable)
-- Find users who have posted in multiple communities
WITH user_community_activity AS (
    SELECT 
        p.user_id,
        COUNT(DISTINCT p.community_id) AS community_count,
        ARRAY_AGG(DISTINCT p.community_id) AS communities
    FROM Posts p
    WHERE p.community_id IS NOT NULL
    GROUP BY p.user_id
)
SELECT 
    u.username,
    uca.community_count AS active_in_communities,
    uca.communities AS community_ids
FROM user_community_activity uca
INNER JOIN Users u ON u.user_id = uca.user_id
WHERE uca.community_count >= 3
ORDER BY uca.community_count DESC;


-- Example 1: Subquery Version (Same logic, less readable)
SELECT 
    u.username,
    community_data.community_count AS active_in_communities,
    community_data.communities AS community_ids
FROM Users u
INNER JOIN (
    SELECT 
        p.user_id,
        COUNT(DISTINCT p.community_id) AS community_count,
        ARRAY_AGG(DISTINCT p.community_id) AS communities
    FROM Posts p
    WHERE p.community_id IS NOT NULL
    GROUP BY p.user_id
    HAVING COUNT(DISTINCT p.community_id) >= 3
) community_data ON u.user_id = community_data.user_id
ORDER BY community_data.community_count DESC;


-- ============================================================================
-- 3.4 Performance Best Practices Summary
-- ============================================================================

/*
WHEN TO USE CTE:
✓ Query readability is important
✓ Need to reference result multiple times
✓ Recursive queries (only option)
✓ Complex multi-step logic
✓ Team collaboration (easier to understand)

WHEN TO USE SUBQUERY:
✓ Simple, one-time use
✓ Small result sets
✓ Correlated subqueries with indexes
✓ EXISTS/NOT EXISTS checks

WHEN TO USE TEMPORARY TABLE:
✓ Result used multiple times in session
✓ Very large intermediate results
✓ Need to index intermediate results
✓ Complex transformations
✓ Batch processing

PERFORMANCE NOTES:
- Modern PostgreSQL optimizes CTEs well
- Use MATERIALIZED/NOT MATERIALIZED hints when needed
- CTEs can be optimization fences (12+: not anymore by default)
- Always EXPLAIN ANALYZE for your specific data
- Indexes matter more than query structure
*/


-- ============================================================================
-- 3.5 Materialized vs Non-Materialized CTEs (PostgreSQL 12+)
-- ============================================================================

-- Force materialization (compute once, store temporarily)
WITH user_stats AS MATERIALIZED (
    SELECT 
        user_id,
        COUNT(*) AS post_count
    FROM Posts
    GROUP BY user_id
)
SELECT * FROM user_stats WHERE post_count > 10;


-- Prevent materialization (inline the CTE)
WITH user_stats AS NOT MATERIALIZED (
    SELECT 
        user_id,
        COUNT(*) AS post_count
    FROM Posts
    GROUP BY user_id
)
SELECT * FROM user_stats WHERE post_count > 10;


-- When to use MATERIALIZED:
-- - CTE result used multiple times in main query
-- - CTE computation is expensive
-- - Result set is small enough to fit in memory

-- When to use NOT MATERIALIZED:
-- - Want optimizer to push down WHERE conditions
-- - CTE used only once
-- - Need index usage from base tables
