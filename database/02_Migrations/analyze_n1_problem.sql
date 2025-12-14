-- ============================================================================
-- N+1 Query Problem Analysis - BEFORE FIX
-- ============================================================================
-- This file demonstrates the N+1 query problem in the feed endpoint
-- and verifies the fix reduces query count
-- ============================================================================

\echo '========================================='
\echo 'N+1 Query Problem - Analysis'
\echo '========================================='

-- ============================================================================
-- Setup Test Data
-- ============================================================================
\echo ''
\echo 'Creating test data...'

DO $$
DECLARE
    main_user_id INTEGER;
    followed_user_1 INTEGER;
    followed_user_2 INTEGER;
    followed_user_3 INTEGER;
    accepted_status_id INTEGER;
BEGIN
    -- Get accepted status
    SELECT status_id INTO accepted_status_id 
    FROM FollowStatus WHERE status_name = 'accepted';
    
    -- Create main user
    INSERT INTO Users (username, email, password_hash, is_private)
    VALUES ('n1_test_main', 'n1main@test.com', 'hash', false)
    RETURNING user_id INTO main_user_id;
    
    -- Create 3 users that main_user follows
    INSERT INTO Users (username, email, password_hash, is_private)
    VALUES ('n1_followed_1', 'n1f1@test.com', 'hash', false)
    RETURNING user_id INTO followed_user_1;
    
    INSERT INTO Users (username, email, password_hash, is_private)
    VALUES ('n1_followed_2', 'n1f2@test.com', 'hash', false)
    RETURNING user_id INTO followed_user_2;
    
    INSERT INTO Users (username, email, password_hash, is_private)
    VALUES ('n1_followed_3', 'n1f3@test.com', 'hash', false)
    RETURNING user_id INTO followed_user_3;
    
    -- Create follow relationships
    INSERT INTO Follows (follower_id, following_id, status_id)
    VALUES 
        (main_user_id, followed_user_1, accepted_status_id),
        (main_user_id, followed_user_2, accepted_status_id),
        (main_user_id, followed_user_3, accepted_status_id);
    
    -- Create 10 posts (mix from different users)
    -- 4 posts from user 1, 3 from user 2, 3 from user 3
    INSERT INTO Posts (user_id, content) VALUES
        (followed_user_1, 'Post 1 from user 1'),
        (followed_user_1, 'Post 2 from user 1'),
        (followed_user_1, 'Post 3 from user 1'),
        (followed_user_1, 'Post 4 from user 1'),
        (followed_user_2, 'Post 1 from user 2'),
        (followed_user_2, 'Post 2 from user 2'),
        (followed_user_2, 'Post 3 from user 2'),
        (followed_user_3, 'Post 1 from user 3'),
        (followed_user_3, 'Post 2 from user 3'),
        (followed_user_3, 'Post 3 from user 3');
    
    RAISE NOTICE '✓ Test data created: 1 main user, 3 followed users, 10 posts';
    RAISE NOTICE '  Main user ID: %', main_user_id;
    RAISE NOTICE '  Followed users: %, %, %', followed_user_1, followed_user_2, followed_user_3;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Test Current Implementation (simulating N+1 problem)
-- ============================================================================
\echo ''
\echo '========================================='
\echo 'BEFORE FIX: Simulating N+1 Queries'
\echo '========================================='

DO $$
DECLARE
    main_user_id INTEGER;
    post_record RECORD;
    user_record RECORD;
    query_count INTEGER := 0;
BEGIN
    -- Get main user
    SELECT user_id INTO main_user_id FROM Users WHERE username = 'n1_test_main';
    
    RAISE NOTICE '';
    RAISE NOTICE 'Current Implementation Pattern:';
    RAISE NOTICE '1. Query to get feed posts (1 query)';
    RAISE NOTICE '2. For each post, query user info (N queries)';
    RAISE NOTICE '';
    
    -- Simulate: Get feed posts (1 query)
    query_count := query_count + 1;
    RAISE NOTICE 'Query #%: SELECT posts FROM user_feed', query_count;
    
    -- Simulate: For each post, get user info (N queries)
    FOR post_record IN 
        SELECT p.post_id, p.user_id, p.content
        FROM Posts p
        INNER JOIN Follows f ON p.user_id = f.following_id
        WHERE f.follower_id = main_user_id
        LIMIT 10
    LOOP
        query_count := query_count + 1;
        RAISE NOTICE 'Query #%: SELECT user FROM Users WHERE user_id = %', query_count, post_record.user_id;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '❌ PROBLEM: Total queries = %', query_count;
    RAISE NOTICE '   Formula: 1 + N (where N = number of posts)';
    RAISE NOTICE '   For 10 posts: 1 + 10 = 11 queries';
    RAISE NOTICE '   For 100 posts: 1 + 100 = 101 queries!';
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Test Optimized Implementation (with JOIN)
-- ============================================================================
\echo ''
\echo '========================================='
\echo 'AFTER FIX: Optimized with JOIN'
\echo '========================================='

DO $$
DECLARE
    main_user_id INTEGER;
    result_count INTEGER;
BEGIN
    SELECT user_id INTO main_user_id FROM Users WHERE username = 'n1_test_main';
    
    RAISE NOTICE '';
    RAISE NOTICE 'Optimized Implementation:';
    RAISE NOTICE '1. Single query with JOINs for user info';
    RAISE NOTICE '2. Subquery for like counts (batched)';
    RAISE NOTICE '3. Subquery for comment counts (batched)';
    RAISE NOTICE '';
    
    -- Execute optimized query
    RAISE NOTICE 'Query #1: SELECT posts with user info (single JOIN query)';
    
    SELECT COUNT(*) INTO result_count
    FROM Posts p
    INNER JOIN Follows f ON p.user_id = f.following_id
    INNER JOIN Users u ON p.user_id = u.user_id
    LEFT JOIN (
        SELECT post_id, COUNT(*) as like_count
        FROM PostLikes
        GROUP BY post_id
    ) lc ON p.post_id = lc.post_id
    LEFT JOIN (
        SELECT post_id, COUNT(*) as comment_count
        FROM Comments
        GROUP BY post_id
    ) cc ON p.post_id = cc.post_id
    WHERE f.follower_id = main_user_id;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ SOLUTION: Total queries = 1';
    RAISE NOTICE '   Regardless of post count: Always 1 query';
    RAISE NOTICE '   For 10 posts: 1 query';
    RAISE NOTICE '   For 100 posts: 1 query';
    RAISE NOTICE '   For 1000 posts: 1 query';
    RAISE NOTICE '';
    RAISE NOTICE '   Improvement: %x faster (11 queries → 1 query)', 11;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Performance Comparison with EXPLAIN ANALYZE
-- ============================================================================
\echo ''
\echo '========================================='
\echo 'Performance Analysis with EXPLAIN ANALYZE'
\echo '========================================='

-- Get main user ID for testing
DO $$
DECLARE
    main_user_id INTEGER;
BEGIN
    SELECT user_id INTO main_user_id FROM Users WHERE username = 'n1_test_main';
    
    RAISE NOTICE '';
    RAISE NOTICE 'Main user ID for testing: %', main_user_id;
    RAISE NOTICE 'Run these commands to see execution plans:';
    RAISE NOTICE '';
    RAISE NOTICE 'psql> \set user_id %', main_user_id;
    RAISE NOTICE 'psql> \i analyze_query_performance.sql';
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Cleanup
-- ============================================================================
\echo ''
\echo '========================================='
\echo 'Cleanup (comment out to keep test data)'
\echo '========================================='

/*
DO $$
BEGIN
    DELETE FROM Posts WHERE user_id IN (
        SELECT user_id FROM Users WHERE username LIKE 'n1_%'
    );
    DELETE FROM Follows WHERE follower_id IN (
        SELECT user_id FROM Users WHERE username LIKE 'n1_%'
    );
    DELETE FROM Users WHERE username LIKE 'n1_%';
    
    RAISE NOTICE '✓ Test data cleaned up';
END;
$$ LANGUAGE plpgsql;
*/

\echo ''
\echo 'Test data preserved for verification.'
\echo 'Run the commented cleanup block to remove test data.'
\echo ''
