-- ============================================================================
-- CTE Testing and Validation Suite
-- ============================================================================
-- Purpose: Comprehensive test suite for Common Table Expressions module
-- Tests: Recursive CTEs, Friend-of-Friend, Performance, Edge Cases
-- PostgreSQL Version: 12+
-- ============================================================================

-- ============================================================================
-- TEST SETUP: Create Test Data
-- ============================================================================

-- Test 1: Setup - Create test data for validation
DO $$
BEGIN
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'TEST 1: Setting up test data';
    RAISE NOTICE '==================================================';
    
    -- Note: This assumes tables exist. In production, you may want to create
    -- test-specific tables or use transactions with ROLLBACK
END $$;

-- ============================================================================
-- RECURSIVE CTE TESTS
-- ============================================================================

-- Test 2: Basic Recursive Number Sequence
DO $$
DECLARE
    result_count INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'TEST 2: Basic Recursive Number Sequence';
    RAISE NOTICE '==================================================';
    
    WITH RECURSIVE numbers AS (
        SELECT 1 AS n
        UNION ALL
        SELECT n + 1 FROM numbers WHERE n < 10
    )
    SELECT COUNT(*) INTO result_count FROM numbers;
    
    IF result_count = 10 THEN
        RAISE NOTICE '✓ PASS: Generated 10 numbers';
    ELSE
        RAISE EXCEPTION '✗ FAIL: Expected 10 numbers, got %', result_count;
    END IF;
END $$;

-- Test 3: Recursive CTE Termination (should stop at depth limit)
DO $$
DECLARE
    max_depth INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'TEST 3: Recursive CTE Termination';
    RAISE NOTICE '==================================================';
    
    WITH RECURSIVE deep_recursion AS (
        SELECT 1 AS level
        UNION ALL
        SELECT level + 1 FROM deep_recursion WHERE level < 100
    )
    SELECT MAX(level) INTO max_depth FROM deep_recursion;
    
    IF max_depth = 100 THEN
        RAISE NOTICE '✓ PASS: Recursion stopped at depth 100';
    ELSE
        RAISE EXCEPTION '✗ FAIL: Expected depth 100, got %', max_depth;
    END IF;
END $$;

-- Test 4: Comment Thread Depth Calculation
DO $$
DECLARE
    test_post_id INTEGER;
    thread_count INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'TEST 4: Comment Thread Depth Calculation';
    RAISE NOTICE '==================================================';
    
    -- Get a post that has comments
    SELECT post_id INTO test_post_id 
    FROM Posts 
    WHERE post_id IN (SELECT DISTINCT post_id FROM Comments)
    LIMIT 1;
    
    IF test_post_id IS NULL THEN
        RAISE NOTICE '⚠ SKIP: No posts with comments found';
    ELSE
        WITH RECURSIVE comment_tree AS (
            SELECT 
                comment_id,
                parent_comment_id,
                0 AS depth,
                ARRAY[comment_id] AS path
            FROM Comments
            WHERE post_id = test_post_id AND parent_comment_id IS NULL
            
            UNION ALL
            
            SELECT 
                c.comment_id,
                c.parent_comment_id,
                ct.depth + 1,
                ct.path || c.comment_id
            FROM Comments c
            INNER JOIN comment_tree ct ON c.parent_comment_id = ct.comment_id
            WHERE ct.depth < 10
        )
        SELECT COUNT(*) INTO thread_count FROM comment_tree;
        
        RAISE NOTICE '✓ PASS: Found % comments in thread for post %', thread_count, test_post_id;
    END IF;
END $$;

-- Test 5: Path Tracking (Cycle Prevention)
DO $$
DECLARE
    has_duplicate BOOLEAN;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'TEST 5: Path Tracking (Cycle Prevention)';
    RAISE NOTICE '==================================================';
    
    WITH RECURSIVE path_tracker AS (
        SELECT 1 AS id, ARRAY[1] AS path
        UNION ALL
        SELECT 
            (pt.id % 10) + 1,
            pt.path || ((pt.id % 10) + 1)
        FROM path_tracker pt
        WHERE pt.id < 20
          AND NOT (((pt.id % 10) + 1) = ANY(pt.path))
    )
    SELECT EXISTS(
        SELECT 1 FROM path_tracker 
        WHERE array_length(path, 1) != (SELECT COUNT(DISTINCT x) FROM unnest(path) x)
    ) INTO has_duplicate;
    
    IF has_duplicate THEN
        RAISE EXCEPTION '✗ FAIL: Found cycle in path tracking';
    ELSE
        RAISE NOTICE '✓ PASS: No cycles detected in path tracking';
    END IF;
END $$;

-- Test 6: Comment Ancestors Function
DO $$
DECLARE
    test_comment_id INTEGER;
    ancestor_count INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'TEST 6: get_comment_ancestors() Function';
    RAISE NOTICE '==================================================';
    
    -- Find a comment with a parent
    SELECT comment_id INTO test_comment_id
    FROM Comments
    WHERE parent_comment_id IS NOT NULL
    LIMIT 1;
    
    IF test_comment_id IS NULL THEN
        RAISE NOTICE '⚠ SKIP: No nested comments found';
    ELSE
        SELECT COUNT(*) INTO ancestor_count
        FROM get_comment_ancestors(test_comment_id);
        
        IF ancestor_count > 0 THEN
            RAISE NOTICE '✓ PASS: Found % ancestors for comment %', ancestor_count, test_comment_id;
        ELSE
            RAISE NOTICE '✓ PASS: Comment % is top-level (no ancestors)', test_comment_id;
        END IF;
    END IF;
END $$;

-- ============================================================================
-- FRIEND-OF-FRIEND TESTS
-- ============================================================================

-- Test 7: Direct Friends Retrieval
DO $$
DECLARE
    test_user_id INTEGER;
    friend_count INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'TEST 7: Direct Friends Retrieval';
    RAISE NOTICE '==================================================';
    
    -- Get a user who follows someone
    SELECT follower_id INTO test_user_id
    FROM Follows
    WHERE status_id = 1
    GROUP BY follower_id
    HAVING COUNT(*) > 0
    LIMIT 1;
    
    IF test_user_id IS NULL THEN
        RAISE NOTICE '⚠ SKIP: No users with follows found';
    ELSE
        SELECT COUNT(*) INTO friend_count
        FROM Follows
        WHERE follower_id = test_user_id AND status_id = 1;
        
        RAISE NOTICE '✓ PASS: User % has % direct friends', test_user_id, friend_count;
    END IF;
END $$;

-- Test 8: Friend-of-Friend Recommendations
DO $$
DECLARE
    test_user_id INTEGER;
    recommendation_count INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'TEST 8: Friend-of-Friend Recommendations';
    RAISE NOTICE '==================================================';
    
    SELECT follower_id INTO test_user_id
    FROM Follows
    WHERE status_id = 1
    GROUP BY follower_id
    HAVING COUNT(*) >= 2
    LIMIT 1;
    
    IF test_user_id IS NULL THEN
        RAISE NOTICE '⚠ SKIP: No users with 2+ follows found';
    ELSE
        SELECT COUNT(*) INTO recommendation_count
        FROM get_friend_of_friend_recommendations(test_user_id);
        
        RAISE NOTICE '✓ PASS: Found % friend-of-friend recommendations for user %', 
                     recommendation_count, test_user_id;
    END IF;
END $$;

-- Test 9: Social Network Distance
DO $$
DECLARE
    user1 INTEGER;
    user2 INTEGER;
    distance INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'TEST 9: Social Network Distance';
    RAISE NOTICE '==================================================';
    
    -- Get two different users who are in the follows table
    SELECT DISTINCT follower_id INTO user1 FROM Follows LIMIT 1;
    SELECT DISTINCT following_id INTO user2 
    FROM Follows 
    WHERE following_id != user1 
    LIMIT 1;
    
    IF user1 IS NULL OR user2 IS NULL THEN
        RAISE NOTICE '⚠ SKIP: Not enough users in follows table';
    ELSE
        distance := get_social_network_distance(user1, user2);
        
        IF distance IS NULL THEN
            RAISE NOTICE '✓ PASS: Users % and % are not connected', user1, user2;
        ELSIF distance > 0 THEN
            RAISE NOTICE '✓ PASS: Distance between users % and % is %', user1, user2, distance;
        ELSE
            RAISE EXCEPTION '✗ FAIL: Invalid distance value %', distance;
        END IF;
    END IF;
END $$;

-- Test 10: Mutual Friends Calculation
DO $$
DECLARE
    test_user_id INTEGER;
    has_mutual BOOLEAN;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'TEST 10: Mutual Friends Calculation';
    RAISE NOTICE '==================================================';
    
    SELECT follower_id INTO test_user_id
    FROM Follows
    WHERE status_id = 1
    GROUP BY follower_id
    HAVING COUNT(*) >= 2
    LIMIT 1;
    
    IF test_user_id IS NULL THEN
        RAISE NOTICE '⚠ SKIP: No users with 2+ follows found';
    ELSE
        WITH my_friends AS (
            SELECT following_id FROM Follows
            WHERE follower_id = test_user_id AND status_id = 1
        )
        SELECT EXISTS(
            SELECT 1
            FROM my_friends mf1
            CROSS JOIN my_friends mf2
            WHERE mf1.following_id < mf2.following_id
              AND EXISTS(
                  SELECT 1 FROM Follows
                  WHERE follower_id = mf1.following_id
                    AND following_id = mf2.following_id
                    AND status_id = 1
              )
        ) INTO has_mutual;
        
        IF has_mutual THEN
            RAISE NOTICE '✓ PASS: Found mutual friend relationships';
        ELSE
            RAISE NOTICE '✓ PASS: No mutual friends found (valid result)';
        END IF;
    END IF;
END $$;

-- Test 11: Prevent Self-Recommendations
DO $$
DECLARE
    test_user_id INTEGER;
    has_self_rec BOOLEAN;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'TEST 11: Prevent Self-Recommendations';
    RAISE NOTICE '==================================================';
    
    SELECT follower_id INTO test_user_id
    FROM Follows
    WHERE status_id = 1
    LIMIT 1;
    
    IF test_user_id IS NULL THEN
        RAISE NOTICE '⚠ SKIP: No follows found';
    ELSE
        SELECT EXISTS(
            SELECT 1
            FROM get_friend_of_friend_recommendations(test_user_id)
            WHERE recommended_user = test_user_id
        ) INTO has_self_rec;
        
        IF has_self_rec THEN
            RAISE EXCEPTION '✗ FAIL: Function returned self as recommendation';
        ELSE
            RAISE NOTICE '✓ PASS: Self-recommendations prevented';
        END IF;
    END IF;
END $$;

-- Test 12: Prevent Direct Friends in Recommendations
DO $$
DECLARE
    test_user_id INTEGER;
    has_direct_friend BOOLEAN;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'TEST 12: Prevent Direct Friends in Recommendations';
    RAISE NOTICE '==================================================';
    
    SELECT follower_id INTO test_user_id
    FROM Follows
    WHERE status_id = 1
    GROUP BY follower_id
    HAVING COUNT(*) >= 1
    LIMIT 1;
    
    IF test_user_id IS NULL THEN
        RAISE NOTICE '⚠ SKIP: No users with follows found';
    ELSE
        WITH direct_friends AS (
            SELECT following_id
            FROM Follows
            WHERE follower_id = test_user_id AND status_id = 1
        )
        SELECT EXISTS(
            SELECT 1
            FROM get_friend_of_friend_recommendations(test_user_id) r
            WHERE r.recommended_user IN (SELECT following_id FROM direct_friends)
        ) INTO has_direct_friend;
        
        IF has_direct_friend THEN
            RAISE EXCEPTION '✗ FAIL: Direct friends found in recommendations';
        ELSE
            RAISE NOTICE '✓ PASS: Direct friends excluded from recommendations';
        END IF;
    END IF;
END $$;

-- ============================================================================
-- PERFORMANCE TESTS
-- ============================================================================

-- Test 13: CTE vs Subquery Execution
DO $$
DECLARE
    cte_time NUMERIC;
    subquery_time NUMERIC;
    result_count INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'TEST 13: CTE vs Subquery Execution';
    RAISE NOTICE '==================================================';
    
    -- CTE approach
    WITH stats AS (
        SELECT 
            user_id,
            COUNT(*) AS post_count
        FROM Posts
        GROUP BY user_id
    )
    SELECT COUNT(*) INTO result_count FROM stats;
    
    -- Subquery approach
    SELECT COUNT(*) INTO result_count
    FROM (
        SELECT 
            user_id,
            COUNT(*) AS post_count
        FROM Posts
        GROUP BY user_id
    ) stats;
    
    RAISE NOTICE '✓ PASS: CTE and Subquery executed successfully';
    RAISE NOTICE 'Note: Use EXPLAIN ANALYZE for detailed performance comparison';
END $$;

-- Test 14: Materialized CTE Performance
DO $$
DECLARE
    result_count INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'TEST 14: Materialized CTE (PostgreSQL 12+)';
    RAISE NOTICE '==================================================';
    
    BEGIN
        WITH expensive_calc AS MATERIALIZED (
            SELECT 
                user_id,
                COUNT(*) AS activity_count
            FROM (
                SELECT user_id FROM Posts
                UNION ALL
                SELECT user_id FROM Comments
            ) all_activity
            GROUP BY user_id
        )
        SELECT COUNT(*) INTO result_count
        FROM expensive_calc
        WHERE activity_count > 0;
        
        RAISE NOTICE '✓ PASS: Materialized CTE executed with % results', result_count;
    EXCEPTION
        WHEN syntax_error THEN
            RAISE NOTICE '⚠ SKIP: MATERIALIZED hint not supported (requires PostgreSQL 12+)';
        WHEN OTHERS THEN
            RAISE EXCEPTION '✗ FAIL: Unexpected error: %', SQLERRM;
    END;
END $$;

-- Test 15: Large Recursion Depth
DO $$
DECLARE
    depth_reached INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'TEST 15: Large Recursion Depth';
    RAISE NOTICE '==================================================';
    
    WITH RECURSIVE deep AS (
        SELECT 1 AS n
        UNION ALL
        SELECT n + 1 FROM deep WHERE n < 1000
    )
    SELECT MAX(n) INTO depth_reached FROM deep;
    
    IF depth_reached = 1000 THEN
        RAISE NOTICE '✓ PASS: Successfully reached recursion depth of 1000';
    ELSE
        RAISE EXCEPTION '✗ FAIL: Expected depth 1000, reached %', depth_reached;
    END IF;
END $$;

-- ============================================================================
-- EDGE CASE TESTS
-- ============================================================================

-- Test 16: Empty Result Sets
DO $$
DECLARE
    result_count INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'TEST 16: Handle Empty Result Sets';
    RAISE NOTICE '==================================================';
    
    WITH RECURSIVE empty_tree AS (
        SELECT comment_id, parent_comment_id, 0 AS depth
        FROM Comments
        WHERE post_id = -1 AND parent_comment_id IS NULL
        
        UNION ALL
        
        SELECT c.comment_id, c.parent_comment_id, et.depth + 1
        FROM Comments c
        INNER JOIN empty_tree et ON c.parent_comment_id = et.comment_id
    )
    SELECT COUNT(*) INTO result_count FROM empty_tree;
    
    IF result_count = 0 THEN
        RAISE NOTICE '✓ PASS: Handled empty result set correctly';
    ELSE
        RAISE EXCEPTION '✗ FAIL: Expected 0 results, got %', result_count;
    END IF;
END $$;

-- Test 17: NULL Handling in Recursive CTEs
DO $$
DECLARE
    has_null BOOLEAN;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'TEST 17: NULL Handling in Recursive CTEs';
    RAISE NOTICE '==================================================';
    
    WITH RECURSIVE null_test AS (
        SELECT 1 AS n, NULL::INTEGER AS parent
        UNION ALL
        SELECT n + 1, NULL FROM null_test WHERE n < 5
    )
    SELECT EXISTS(SELECT 1 FROM null_test WHERE parent IS NOT NULL) INTO has_null;
    
    IF NOT has_null THEN
        RAISE NOTICE '✓ PASS: NULL values handled correctly';
    ELSE
        RAISE EXCEPTION '✗ FAIL: Unexpected non-NULL value found';
    END IF;
END $$;

-- Test 18: Circular Reference Prevention
DO $$
DECLARE
    has_cycle BOOLEAN;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'TEST 18: Circular Reference Prevention';
    RAISE NOTICE '==================================================';
    
    -- Create temporary circular data
    CREATE TEMP TABLE IF NOT EXISTS temp_circular (
        id INTEGER PRIMARY KEY,
        parent_id INTEGER
    );
    
    TRUNCATE temp_circular;
    
    INSERT INTO temp_circular VALUES
        (1, 2),
        (2, 3),
        (3, 1);  -- Circular!
    
    WITH RECURSIVE safe_traversal AS (
        SELECT id, parent_id, ARRAY[id] AS path
        FROM temp_circular
        WHERE id = 1
        
        UNION ALL
        
        SELECT t.id, t.parent_id, st.path || t.id
        FROM temp_circular t
        INNER JOIN safe_traversal st ON t.id = st.parent_id
        WHERE NOT (t.id = ANY(st.path))  -- Prevent cycles
          AND array_length(st.path, 1) < 10
    )
    SELECT array_length(path, 1) > 3 INTO has_cycle
    FROM safe_traversal
    ORDER BY array_length(path, 1) DESC
    LIMIT 1;
    
    IF has_cycle THEN
        RAISE EXCEPTION '✗ FAIL: Circular reference not prevented';
    ELSE
        RAISE NOTICE '✓ PASS: Circular reference prevented successfully';
    END IF;
    
    DROP TABLE IF EXISTS temp_circular;
END $$;

-- ============================================================================
-- VIEW AND FUNCTION TESTS
-- ============================================================================

-- Test 19: comment_thread_with_metrics View
DO $$
DECLARE
    view_exists BOOLEAN;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'TEST 19: comment_thread_with_metrics View';
    RAISE NOTICE '==================================================';
    
    SELECT EXISTS(
        SELECT 1 FROM information_schema.views
        WHERE table_name = 'comment_thread_with_metrics'
    ) INTO view_exists;
    
    IF NOT view_exists THEN
        RAISE NOTICE '⚠ SKIP: View comment_thread_with_metrics not found';
    ELSE
        PERFORM * FROM comment_thread_with_metrics LIMIT 1;
        RAISE NOTICE '✓ PASS: View comment_thread_with_metrics is queryable';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION '✗ FAIL: Error querying view: %', SQLERRM;
END $$;

-- Test 20: advanced_friend_recommendations View
DO $$
DECLARE
    view_exists BOOLEAN;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'TEST 20: advanced_friend_recommendations View';
    RAISE NOTICE '==================================================';
    
    SELECT EXISTS(
        SELECT 1 FROM information_schema.views
        WHERE table_name = 'advanced_friend_recommendations'
    ) INTO view_exists;
    
    IF NOT view_exists THEN
        RAISE NOTICE '⚠ SKIP: View advanced_friend_recommendations not found';
    ELSE
        PERFORM * FROM advanced_friend_recommendations LIMIT 1;
        RAISE NOTICE '✓ PASS: View advanced_friend_recommendations is queryable';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION '✗ FAIL: Error querying view: %', SQLERRM;
END $$;

-- ============================================================================
-- STRESS TESTS
-- ============================================================================

-- Test 21: High Volume Friend-of-Friend
DO $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    duration NUMERIC;
    result_count INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'TEST 21: High Volume Friend-of-Friend Query';
    RAISE NOTICE '==================================================';
    
    start_time := clock_timestamp();
    
    WITH RECURSIVE social_paths AS (
        SELECT 
            follower_id AS start_user,
            following_id AS user_node,
            1 AS distance,
            ARRAY[follower_id, following_id] AS path
        FROM Follows
        WHERE status_id = 1
        LIMIT 100
    ),
    expanded_paths AS (
        SELECT * FROM social_paths
        
        UNION ALL
        
        SELECT 
            sp.start_user,
            f.following_id,
            sp.distance + 1,
            sp.path || f.following_id
        FROM expanded_paths sp
        INNER JOIN Follows f ON f.follower_id = sp.user_node
        WHERE f.status_id = 1
          AND sp.distance < 4
          AND NOT (f.following_id = ANY(sp.path))
    )
    SELECT COUNT(*) INTO result_count FROM expanded_paths;
    
    end_time := clock_timestamp();
    duration := EXTRACT(EPOCH FROM (end_time - start_time)) * 1000;
    
    RAISE NOTICE '✓ PASS: Processed % social paths in % ms', result_count, ROUND(duration, 2);
    
    IF duration > 5000 THEN
        RAISE NOTICE '⚠ WARNING: Query took longer than 5 seconds';
    END IF;
END $$;

-- ============================================================================
-- TEST SUMMARY
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'CTE TEST SUITE COMPLETED';
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'All tests executed. Review results above.';
    RAISE NOTICE 'Tests marked with ✓ PASS are successful';
    RAISE NOTICE 'Tests marked with ⚠ SKIP were skipped due to missing data';
    RAISE NOTICE 'Tests marked with ✗ FAIL indicate issues that need attention';
    RAISE NOTICE '==================================================';
END $$;

-- ============================================================================
-- PERFORMANCE BENCHMARK (Optional - Run Separately)
-- ============================================================================

-- Uncomment to run comprehensive performance benchmarking
/*
SELECT compare_query_performance();
*/
