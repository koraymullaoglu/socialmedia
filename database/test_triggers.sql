-- Test Script for Database Triggers
-- This script tests all the triggers we've created

\echo '========================================='
\echo 'TESTING DATABASE TRIGGERS'
\echo '========================================='

-- =====================================================
-- TEST 1: Test updated_at triggers
-- =====================================================
\echo ''
\echo 'TEST 1: Testing updated_at triggers...'
\echo '---------------------------------------'

-- Create a test user
INSERT INTO Users (username, email, password_hash, bio)
VALUES ('trigger_test_user', 'trigger@test.com', 'hash123', 'Test bio')
RETURNING user_id, username, created_at, updated_at;

-- Wait a moment and update the user
SELECT pg_sleep(1);
UPDATE Users 
SET bio = 'Updated bio' 
WHERE username = 'trigger_test_user'
RETURNING user_id, username, bio, created_at, updated_at;

-- Verify updated_at changed
SELECT 
    username,
    bio,
    created_at,
    updated_at,
    (updated_at > created_at) AS updated_at_changed
FROM Users 
WHERE username = 'trigger_test_user';

-- =====================================================
-- TEST 2: Test audit log trigger for user deletion
-- =====================================================
\echo ''
\echo 'TEST 2: Testing audit log trigger...'
\echo '---------------------------------------'

-- Check audit log before deletion
SELECT COUNT(*) AS audit_entries_before FROM AuditLog;

-- Delete the test user (should trigger audit log)
DELETE FROM Users WHERE username = 'trigger_test_user';

-- Check audit log after deletion
SELECT 
    table_name,
    operation,
    username,
    email,
    record_data->>'bio' AS bio,
    deleted_at
FROM AuditLog 
WHERE username = 'trigger_test_user';

-- =====================================================
-- TEST 3: Test cascade cleanup triggers for posts
-- =====================================================
\echo ''
\echo 'TEST 3: Testing cascade cleanup triggers...'
\echo '---------------------------------------'

-- Create a test user and post
INSERT INTO Users (username, email, password_hash)
VALUES ('post_test_user', 'posttest@test.com', 'hash456')
RETURNING user_id;

-- Get the user_id (store it for later use)
DO $$
DECLARE
    v_user_id INT;
    v_post_id INT;
BEGIN
    -- Get user id
    SELECT user_id INTO v_user_id FROM Users WHERE username = 'post_test_user';
    
    -- Create a test post
    INSERT INTO Posts (user_id, content)
    VALUES (v_user_id, 'Test post for trigger testing')
    RETURNING post_id INTO v_post_id;
    
    RAISE NOTICE 'Created post_id: %', v_post_id;
    
    -- Add some likes
    INSERT INTO PostLikes (post_id, user_id)
    VALUES (v_post_id, v_user_id);
    
    -- Add some comments
    INSERT INTO Comments (post_id, user_id, content)
    VALUES (v_post_id, v_user_id, 'Test comment 1');
    
    INSERT INTO Comments (post_id, user_id, content)
    VALUES (v_post_id, v_user_id, 'Test comment 2');
    
    -- Display counts before deletion
    RAISE NOTICE 'Likes count before: %', (SELECT COUNT(*) FROM PostLikes WHERE post_id = v_post_id);
    RAISE NOTICE 'Comments count before: %', (SELECT COUNT(*) FROM Comments WHERE post_id = v_post_id);
    
    -- Delete the post (should trigger cleanup)
    DELETE FROM Posts WHERE post_id = v_post_id;
    
    -- Verify cleanup (should be 0)
    RAISE NOTICE 'Likes count after: %', (SELECT COUNT(*) FROM PostLikes WHERE post_id = v_post_id);
    RAISE NOTICE 'Comments count after: %', (SELECT COUNT(*) FROM Comments WHERE post_id = v_post_id);
END $$;

-- Cleanup test data
DELETE FROM Users WHERE username = 'post_test_user';

-- =====================================================
-- TEST 4: Verify all triggers are active
-- =====================================================
\echo ''
\echo 'TEST 4: Verifying all triggers are active...'
\echo '---------------------------------------'

SELECT 
    trigger_name,
    event_object_table AS table_name,
    action_timing AS timing,
    event_manipulation AS event,
    action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

\echo ''
\echo '========================================='
\echo 'ALL TRIGGER TESTS COMPLETED!'
\echo '========================================='
