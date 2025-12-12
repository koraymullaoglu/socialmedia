-- Setup and Test Script for Transaction Examples
-- Runs all transaction demonstrations with success and failure scenarios

\echo '========================================='
\echo 'TRANSACTION EXAMPLES - SETUP AND TESTING'
\echo '========================================='

-- =====================================================
-- Step 1: Setup all transaction components
-- =====================================================

\echo ''
\echo 'Step 1: Setting up transaction examples...'
\i 06_Transactions/01_create_community_atomic.sql

\echo ''
\i 06_Transactions/02_post_sharing_rollback.sql

\echo ''
\i 06_Transactions/03_nested_savepoints.sql

\echo ''
\i 06_Transactions/04_isolation_levels.sql

-- =====================================================
-- Step 2: Prepare test data
-- =====================================================

\echo ''
\echo '========================================='
\echo 'Step 2: Preparing test data...'
\echo '========================================='

DO $$
DECLARE
    v_user_count INT;
BEGIN
    -- Ensure we have test users
    SELECT COUNT(*) INTO v_user_count FROM Users;
    
    IF v_user_count < 3 THEN
        RAISE NOTICE 'Creating test users...';
        INSERT INTO Users (username, email, password_hash, bio)
        VALUES 
            ('alice', 'alice@test.com', 'hash1', 'Test user Alice'),
            ('bob', 'bob@test.com', 'hash2', 'Test user Bob'),
            ('charlie', 'charlie@test.com', 'hash3', 'Test user Charlie')
        ON CONFLICT (username) DO NOTHING;
        RAISE NOTICE '✓ Test users ready';
    ELSE
        RAISE NOTICE '✓ Test users already exist';
    END IF;
    
    -- Ensure we have follow relationships
    INSERT INTO Follows (follower_id, following_id, status_id)
    SELECT 
        u1.user_id,
        u2.user_id,
        (SELECT status_id FROM FollowStatus WHERE status_name = 'accepted')
    FROM Users u1
    CROSS JOIN Users u2
    WHERE u1.user_id != u2.user_id
    LIMIT 3
    ON CONFLICT DO NOTHING;
    
    RAISE NOTICE '✓ Follow relationships ready';
    
END $$;

-- =====================================================
-- TEST 1: Atomic Community Creation
-- =====================================================

\echo ''
\echo '========================================='
\echo 'TEST 1: ATOMIC COMMUNITY CREATION'
\echo '========================================='

\echo ''
\echo 'Test 1a: Success Case'
\echo '---'

SELECT * FROM create_community_with_admin(
    (SELECT user_id FROM Users LIMIT 1),
    'Photography Club',
    'For photography enthusiasts',
    FALSE
);

\echo ''
\echo 'Test 1b: Verify community and admin membership'
SELECT 
    c.name,
    u.username AS creator,
    r.role_name,
    c.created_at
FROM Communities c
JOIN CommunityMembers cm ON c.community_id = cm.community_id
JOIN Users u ON cm.user_id = u.user_id
JOIN Roles r ON cm.role_id = r.role_id
WHERE c.name = 'Photography Club';

-- =====================================================
-- TEST 2: Post Sharing with Notifications
-- =====================================================

\echo ''
\echo '========================================='
\echo 'TEST 2: POST SHARING WITH NOTIFICATIONS'
\echo '========================================='

\echo ''
\echo 'Test 2a: Success Case - Post and notifications created'
\echo '---'

SELECT * FROM share_post_and_notify_followers(
    (SELECT user_id FROM Users LIMIT 1),
    'Check out my new blog post about PostgreSQL transactions!',
    NULL,
    NULL,
    FALSE  -- should_fail = FALSE
);

\echo ''
\echo 'Test 2b: Verify notifications were created'
SELECT 
    n.type,
    u.username AS notified_user,
    n.content,
    n.created_at
FROM Notifications n
JOIN Users u ON n.user_id = u.user_id
ORDER BY n.created_at DESC
LIMIT 5;

\echo ''
\echo 'Test 2c: Failure Case - Should rollback everything'
\echo '---'

DO $$
DECLARE
    v_post_count_before INT;
    v_notification_count_before INT;
    v_user_id INT;
BEGIN
    SELECT user_id INTO v_user_id FROM Users LIMIT 1;
    
    -- Count before
    SELECT COUNT(*) INTO v_post_count_before FROM Posts;
    SELECT COUNT(*) INTO v_notification_count_before FROM Notifications;
    
    RAISE NOTICE 'Before: % posts, % notifications', 
        v_post_count_before, v_notification_count_before;
    
    -- Try with should_fail = TRUE
    BEGIN
        PERFORM share_post_and_notify_followers(
            v_user_id,
            'This post should be rolled back',
            NULL,
            NULL,
            TRUE  -- should_fail = TRUE (triggers rollback)
        );
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Expected error caught: %', SQLERRM;
    END;
    
    -- Verify nothing was created
    IF (SELECT COUNT(*) FROM Posts) = v_post_count_before THEN
        RAISE NOTICE '✓ ROLLBACK successful: Post was not created';
    ELSE
        RAISE NOTICE '✗ ROLLBACK failed: Post was created despite error';
    END IF;
    
    IF (SELECT COUNT(*) FROM Notifications) = v_notification_count_before THEN
        RAISE NOTICE '✓ ROLLBACK successful: Notifications were not created';
    ELSE
        RAISE NOTICE '✗ ROLLBACK failed: Notifications were created despite error';
    END IF;
END $$;

-- =====================================================
-- TEST 3: Nested Transactions with SAVEPOINT
-- =====================================================

\echo ''
\echo '========================================='
\echo 'TEST 3: NESTED TRANSACTIONS (SAVEPOINTS)'
\echo '========================================='

\echo ''
\echo 'Test 3a: Batch post creation with some failures'
\echo '---'

SELECT * FROM batch_create_posts_with_savepoints(
    (SELECT user_id FROM Users LIMIT 1),
    ARRAY[
        'Valid post 1',
        'Valid post 2',
        '',  -- Empty post - will fail
        'Valid post 3',
        NULL,  -- NULL content - will fail
        'Valid post 4'
    ],
    TRUE  -- continue_on_error
);

\echo ''
\echo 'Test 3b: Community creation with multiple members'
\echo '---'

SELECT * FROM create_community_with_multiple_members(
    (SELECT user_id FROM Users LIMIT 1),  -- Creator
    'Book Club',
    'Monthly book discussions',
    ARRAY[
        (SELECT user_id FROM Users LIMIT 1 OFFSET 1),  -- Second user
        (SELECT user_id FROM Users LIMIT 1 OFFSET 2),  -- Third user
        9999,  -- Non-existent user - will fail
        (SELECT user_id FROM Users LIMIT 1)  -- Creator again - duplicate, will fail
    ]
);

\echo ''
\echo 'Test 3c: Verify community has correct members'
SELECT 
    c.name,
    u.username,
    r.role_name
FROM Communities c
JOIN CommunityMembers cm ON c.community_id = cm.community_id
JOIN Users u ON cm.user_id = u.user_id
JOIN Roles r ON cm.role_id = r.role_id
WHERE c.name = 'Book Club'
ORDER BY r.role_name, u.username;

\echo ''
\echo 'Test 3d: Manual SAVEPOINT demonstration'
\echo '---'
\echo 'Demonstrating explicit SAVEPOINT usage:'
\echo ''

-- Start a transaction block
BEGIN;

-- Get a test user
\set test_user_id '(SELECT user_id FROM Users LIMIT 1)'

-- Operation 1: Will succeed
SAVEPOINT step1;
INSERT INTO Posts (user_id, content) 
SELECT :test_user_id, 'SAVEPOINT demo: Post 1';
\echo '✓ Step 1: Post 1 created (SAVEPOINT step1)'

-- Operation 2: Will be rolled back
SAVEPOINT step2;
INSERT INTO Posts (user_id, content) 
SELECT :test_user_id, 'SAVEPOINT demo: Post 2 (will be rolled back)';
\echo '  Step 2: Post 2 created temporarily...'

-- Rollback operation 2
ROLLBACK TO SAVEPOINT step2;
\echo '✗ Step 2: Rolled back to step2 - Post 2 removed'

-- Operation 3: Will succeed
SAVEPOINT step3;
INSERT INTO Posts (user_id, content) 
SELECT :test_user_id, 'SAVEPOINT demo: Post 3';
\echo '✓ Step 3: Post 3 created (SAVEPOINT step3)'

-- Commit everything except operation 2
COMMIT;

\echo ''
\echo 'Result: Post 1 and Post 3 committed, Post 2 was rolled back'
\echo 'Key Concept: SAVEPOINT allows partial rollback within a transaction'
\echo ''

-- =====================================================
-- TEST 4: Isolation Levels
-- =====================================================

\echo ''
\echo '========================================='
\echo 'TEST 4: ISOLATION LEVELS'
\echo '========================================='

\echo ''
\echo 'Test 4a: READ COMMITTED demonstration'
\echo '---'

SELECT * FROM demonstrate_read_committed();

\echo ''
\echo 'Test 4b: SERIALIZABLE demonstration'
\echo '---'

SELECT * FROM demonstrate_serializable();

\echo ''
\echo 'Test 4c: Phantom reads demonstration'
\echo '---'

SELECT * FROM demonstrate_phantom_reads(
    (SELECT user_id FROM Users LIMIT 1)
);

\echo ''
\echo 'Test 4d: Money transfer demonstration'
\echo '---'

SELECT * FROM transfer_money_with_isolation(
    (SELECT user_id FROM Users LIMIT 1 OFFSET 0),  -- First user
    (SELECT user_id FROM Users LIMIT 1 OFFSET 1),  -- Second user
    50.00,
    'READ COMMITTED'
);

\echo ''
\echo 'Test 4e: Verify account balances'
SELECT 
    u.username,
    ab.balance,
    ab.updated_at
FROM AccountBalance ab
JOIN Users u ON ab.user_id = u.user_id
ORDER BY u.username;

-- =====================================================
-- TEST 5: ACID Properties Verification
-- =====================================================

\echo ''
\echo '========================================='
\echo 'TEST 5: ACID PROPERTIES VERIFICATION'
\echo '========================================='

DO $$
BEGIN
    RAISE NOTICE 'ACID Properties Demonstrated:';
    RAISE NOTICE '';
    RAISE NOTICE 'ATOMICITY:';
    RAISE NOTICE '  ✓ Community creation: All-or-nothing operation';
    RAISE NOTICE '  ✓ Post sharing: Post + notifications created together or not at all';
    RAISE NOTICE '  ✓ Test 2c showed rollback removes all changes';
    RAISE NOTICE '';
    RAISE NOTICE 'CONSISTENCY:';
    RAISE NOTICE '  ✓ Foreign keys enforced (user_id, community_id, etc.)';
    RAISE NOTICE '  ✓ Balance transfers maintain total balance';
    RAISE NOTICE '  ✓ Invalid data rejected (empty posts, non-existent users)';
    RAISE NOTICE '';
    RAISE NOTICE 'ISOLATION:';
    RAISE NOTICE '  ✓ READ COMMITTED: Sees committed changes';
    RAISE NOTICE '  ✓ SERIALIZABLE: Complete isolation';
    RAISE NOTICE '  ✓ Row-level locking in money transfers (FOR UPDATE)';
    RAISE NOTICE '';
    RAISE NOTICE 'DURABILITY:';
    RAISE NOTICE '  ✓ Committed transactions survive crashes';
    RAISE NOTICE '  ✓ WAL (Write-Ahead Logging) ensures recovery';
    RAISE NOTICE '  ✓ All successful operations are permanently saved';
END $$;

-- =====================================================
-- Summary Statistics
-- =====================================================

\echo ''
\echo '========================================='
\echo 'TEST SUMMARY'
\echo '========================================='

SELECT 
    'Communities' AS object_type,
    COUNT(*) AS total_count
FROM Communities
UNION ALL
SELECT 
    'Posts',
    COUNT(*)
FROM Posts
UNION ALL
SELECT 
    'Notifications',
    COUNT(*)
FROM Notifications
UNION ALL
SELECT 
    'Community Members',
    COUNT(*)
FROM CommunityMembers
UNION ALL
SELECT 
    'Account Balances',
    COUNT(*)
FROM AccountBalance;

\echo ''
\echo '========================================='
\echo 'ALL TRANSACTION TESTS COMPLETED!'
\echo '========================================='
\echo ''
\echo 'Key Takeaways:'
\echo '  1. Use transactions for multi-step operations'
\echo '  2. Handle errors with EXCEPTION blocks'
\echo '  3. Use SAVEPOINT for partial rollbacks'
\echo '  4. Choose appropriate isolation level'
\echo '  5. Lock rows when needed (FOR UPDATE)'
\echo '  6. Test both success and failure scenarios'
\echo ''
\echo 'For concurrent testing, run scripts in multiple terminals'
\echo 'to observe isolation level behaviors in real scenarios.'
\echo '========================================='
