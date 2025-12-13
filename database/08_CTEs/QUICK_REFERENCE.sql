-- ============================================================================
-- CTE Quick Reference Guide
-- ============================================================================
-- Fast lookup for common CTE patterns and function usage
-- ============================================================================

-- ============================================================================
-- QUICK FUNCTION REFERENCE
-- ============================================================================

-- 1. Get Comment Thread
SELECT * FROM get_comment_thread(post_id);

-- 2. Get Comment Ancestors
SELECT * FROM get_comment_ancestors(comment_id);

-- 3. Get Friend Recommendations
SELECT * FROM get_friend_of_friend_recommendations(user_id);

-- 4. Get Social Distance
SELECT get_social_network_distance(from_user, to_user);

-- 5. Compare Performance
SELECT * FROM compare_query_performance();

-- ============================================================================
-- QUICK VIEW REFERENCE
-- ============================================================================

-- 1. Comment Threads with Metrics
SELECT * FROM comment_thread_with_metrics WHERE post_id = 1;

-- 2. Friend Recommendations (All Users)
SELECT * FROM advanced_friend_recommendations WHERE user_id = 1;

-- ============================================================================
-- COMMON PATTERNS - COPY & PASTE READY
-- ============================================================================

-- PATTERN 1: Simple Number Sequence
-- --------------------------------
WITH RECURSIVE numbers AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM numbers WHERE n < 100
)
SELECT * FROM numbers;

-- PATTERN 2: Date Range Generator
-- --------------------------------
WITH RECURSIVE dates AS (
    SELECT CURRENT_DATE AS date
    UNION ALL
    SELECT date + INTERVAL '1 day' 
    FROM dates 
    WHERE date < CURRENT_DATE + INTERVAL '30 days'
)
SELECT date, TO_CHAR(date, 'Day') AS day_name FROM dates;

-- PATTERN 3: Hierarchy Traversal
-- --------------------------------
WITH RECURSIVE hierarchy AS (
    -- Base: Root level
    SELECT 
        id,
        parent_id,
        0 AS level,
        ARRAY[id] AS path
    FROM table_name
    WHERE parent_id IS NULL
    
    UNION ALL
    
    -- Recursive: Children
    SELECT 
        t.id,
        t.parent_id,
        h.level + 1,
        h.path || t.id
    FROM table_name t
    INNER JOIN hierarchy h ON t.parent_id = h.id
    WHERE h.level < 10  -- Depth limit
)
SELECT * FROM hierarchy ORDER BY path;

-- PATTERN 4: Graph Traversal (Shortest Path)
-- -------------------------------------------
WITH RECURSIVE paths AS (
    -- Base: Starting node
    SELECT 
        node_id AS current_node,
        1 AS distance,
        ARRAY[node_id] AS path
    FROM graph
    WHERE node_id = 1  -- Start node
    
    UNION ALL
    
    -- Recursive: Expand to neighbors
    SELECT 
        g.next_node,
        p.distance + 1,
        p.path || g.next_node
    FROM paths p
    INNER JOIN graph g ON g.node_id = p.current_node
    WHERE p.distance < 10
      AND NOT (g.next_node = ANY(p.path))  -- Prevent cycles
)
SELECT * FROM paths WHERE current_node = 100;  -- Target node

-- PATTERN 5: Multiple CTEs Pipeline
-- ----------------------------------
WITH 
step1_filter AS (
    SELECT * FROM table1 WHERE condition
),
step2_join AS (
    SELECT s1.*, t2.column
    FROM step1_filter s1
    INNER JOIN table2 t2 ON s1.id = t2.id
),
step3_aggregate AS (
    SELECT 
        group_col,
        COUNT(*) AS count,
        SUM(value) AS total
    FROM step2_join
    GROUP BY group_col
)
SELECT * FROM step3_aggregate ORDER BY total DESC;

-- PATTERN 6: Recursive Aggregation
-- ---------------------------------
WITH RECURSIVE agg AS (
    -- Base
    SELECT 
        id,
        parent_id,
        value,
        value AS cumulative
    FROM table_name
    WHERE parent_id IS NULL
    
    UNION ALL
    
    -- Recursive
    SELECT 
        t.id,
        t.parent_id,
        t.value,
        a.cumulative + t.value
    FROM table_name t
    INNER JOIN agg a ON t.parent_id = a.id
)
SELECT * FROM agg;

-- PATTERN 7: Cycle Detection
-- ---------------------------
WITH RECURSIVE check_cycles AS (
    SELECT 
        id,
        parent_id,
        ARRAY[id] AS path,
        FALSE AS has_cycle
    FROM table_name
    
    UNION ALL
    
    SELECT 
        t.id,
        t.parent_id,
        cc.path || t.id,
        t.id = ANY(cc.path) AS has_cycle
    FROM table_name t
    INNER JOIN check_cycles cc ON t.parent_id = cc.id
    WHERE NOT cc.has_cycle
      AND array_length(cc.path, 1) < 100
)
SELECT * FROM check_cycles WHERE has_cycle;

-- ============================================================================
-- QUICK SYNTAX REFERENCE
-- ============================================================================

-- RECURSIVE CTE TEMPLATE
-- -----------------------
/*
WITH RECURSIVE cte_name AS (
    -- BASE CASE (non-recursive term)
    SELECT ... WHERE <base_condition>
    
    UNION ALL
    
    -- RECURSIVE CASE (recursive term)
    SELECT ... 
    FROM cte_name
    WHERE <termination_condition>
)
SELECT * FROM cte_name;
*/

-- NON-RECURSIVE CTE TEMPLATE
-- ---------------------------
/*
WITH
cte1 AS (SELECT ...),
cte2 AS (SELECT ... FROM cte1),
cte3 AS (SELECT ... FROM cte2)
SELECT * FROM cte3;
*/

-- MATERIALIZATION CONTROL (PostgreSQL 12+)
-- -----------------------------------------
/*
WITH cte AS MATERIALIZED (...)      -- Force materialization
WITH cte AS NOT MATERIALIZED (...)  -- Prevent materialization
*/

-- ============================================================================
-- TERMINATION CONDITIONS (CRITICAL!)
-- ============================================================================

-- 1. Depth Limit
WHERE depth < 10

-- 2. Cycle Prevention
WHERE NOT (new_id = ANY(path))

-- 3. Distance Limit
WHERE distance < 6

-- 4. Time-based
WHERE created_at > NOW() - INTERVAL '30 days'

-- 5. Combined
WHERE depth < 10 AND NOT (id = ANY(path))

-- ============================================================================
-- PATH TRACKING PATTERNS
-- ============================================================================

-- Array Path (Most Common)
ARRAY[id] AS path                    -- Initialize
path || new_id                       -- Append
NOT (new_id = ANY(path))            -- Check existence
array_length(path, 1)               -- Get length

-- String Path (Readable)
id::TEXT AS path                     -- Initialize
path || '->' || new_id::TEXT        -- Append
path LIKE '%' || new_id::TEXT || '%' -- Check (less efficient)

-- ============================================================================
-- COMMON USE CASES - ONE-LINERS
-- ============================================================================

-- Display Comment Thread with Indentation
SELECT REPEAT('  ', depth) || '└─ ' || username AS thread, content
FROM get_comment_thread(1) ORDER BY path;

-- Find Friend Recommendations
SELECT username, mutual_friends FROM get_friend_of_friend_recommendations(1) LIMIT 10;

-- Calculate Degrees of Separation
SELECT get_social_network_distance(1, 100) AS degrees;

-- Get All Thread Participants
SELECT DISTINCT username FROM get_comment_thread(1);

-- Find Deepest Threads
SELECT post_id, MAX(depth) AS max_depth FROM get_comment_thread(post_id) GROUP BY post_id;

-- Count Replies per Level
SELECT depth, COUNT(*) AS replies FROM get_comment_thread(1) GROUP BY depth;

-- ============================================================================
-- PERFORMANCE TIPS
-- ============================================================================

-- 1. Add LIMIT to large result sets
SELECT * FROM get_comment_thread(1) LIMIT 100;

-- 2. Filter by depth
SELECT * FROM get_comment_thread(1) WHERE depth <= 3;

-- 3. Use EXPLAIN ANALYZE
EXPLAIN ANALYZE SELECT * FROM get_comment_thread(1);

-- 4. Materialize expensive CTEs (PostgreSQL 12+)
WITH data AS MATERIALIZED (SELECT expensive_operation()) SELECT * FROM data;

-- 5. Index recursive join columns
-- CREATE INDEX ON Comments(parent_comment_id);
-- CREATE INDEX ON Follows(follower_id, following_id);

-- ============================================================================
-- DEBUGGING TIPS
-- ============================================================================

-- 1. Test base case only
WITH RECURSIVE test AS (
    SELECT * FROM table WHERE parent_id IS NULL  -- Base case only
)
SELECT * FROM test;

-- 2. Add row numbers to track iterations
WITH RECURSIVE test AS (
    SELECT id, 1 AS iteration FROM table WHERE parent_id IS NULL
    UNION ALL
    SELECT t.id, test.iteration + 1 FROM table t 
    INNER JOIN test ON t.parent_id = test.id
    WHERE test.iteration < 5
)
SELECT * FROM test;

-- 3. Check path building
WITH RECURSIVE test AS (
    SELECT id, ARRAY[id] AS path FROM table WHERE parent_id IS NULL
    UNION ALL
    SELECT t.id, test.path || t.id FROM table t
    INNER JOIN test ON t.parent_id = test.id
    WHERE array_length(test.path, 1) < 5
)
SELECT id, path, array_length(path, 1) AS depth FROM test;

-- ============================================================================
-- INTEGRATION EXAMPLES
-- ============================================================================

-- CTE + Window Function
WITH thread AS (
    SELECT * FROM get_comment_thread(1)
)
SELECT 
    *,
    RANK() OVER (PARTITION BY depth ORDER BY created_at) AS rank_in_level
FROM thread;

-- CTE + Aggregation
WITH thread AS (
    SELECT * FROM get_comment_thread(1)
)
SELECT 
    depth,
    COUNT(*) AS comment_count,
    AVG(LENGTH(content)) AS avg_length
FROM thread
GROUP BY depth;

-- CTE + JOIN
WITH recommendations AS (
    SELECT * FROM get_friend_of_friend_recommendations(1)
)
SELECT 
    r.*,
    u.email,
    u.created_at
FROM recommendations r
INNER JOIN Users u ON u.user_id = r.recommended_user;

-- Multiple CTEs + Final Query
WITH 
threads AS (SELECT * FROM get_comment_thread(1)),
participants AS (SELECT DISTINCT user_id FROM threads),
user_stats AS (
    SELECT 
        p.user_id,
        COUNT(DISTINCT t.comment_id) AS comment_count
    FROM participants p
    LEFT JOIN threads t ON t.user_id = p.user_id
    GROUP BY p.user_id
)
SELECT * FROM user_stats ORDER BY comment_count DESC;

-- ============================================================================
-- ERROR MESSAGES & SOLUTIONS
-- ============================================================================

/*
ERROR: infinite recursion detected
SOLUTION: Add termination condition (WHERE depth < 10)

ERROR: out of shared memory
SOLUTION: Increase work_mem or add LIMIT

ERROR: stack depth limit exceeded
SOLUTION: Reduce recursion depth limit

ERROR: type mismatch in UNION
SOLUTION: Ensure both parts of UNION have same column types
*/

-- ============================================================================
-- QUICK TESTS
-- ============================================================================

-- Test 1: Basic Recursion
WITH RECURSIVE test AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM test WHERE n < 5
)
SELECT * FROM test;  -- Should return 1,2,3,4,5

-- Test 2: Path Tracking
WITH RECURSIVE test AS (
    SELECT 1 AS n, ARRAY[1] AS path
    UNION ALL
    SELECT n + 1, path || (n + 1) FROM test WHERE n < 5
)
SELECT n, path FROM test;  -- Should show growing paths

-- Test 3: Cycle Prevention
WITH RECURSIVE test AS (
    SELECT 1 AS n, ARRAY[1] AS path
    UNION ALL
    SELECT (n % 3) + 1, path || ((n % 3) + 1) 
    FROM test 
    WHERE n < 10 AND NOT (((n % 3) + 1) = ANY(path))
)
SELECT * FROM test;  -- Should stop when cycle detected

-- ============================================================================
-- END OF QUICK REFERENCE
-- ============================================================================
-- For detailed documentation, see CTE_README.md
-- For examples, see 02_practical_examples.sql
-- For testing, see 03_testing_validation.sql
-- ============================================================================
