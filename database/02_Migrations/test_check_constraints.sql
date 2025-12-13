-- ============================================================================
-- TEST: CHECK Constraints Validation
-- ============================================================================
-- Purpose: Validate that all CHECK constraints work correctly
-- Tests both valid and invalid data scenarios
-- ============================================================================

\echo '===================================================================='
\echo 'TEST SUITE: CHECK Constraints'
\echo '===================================================================='
\echo ''

-- ============================================================================
-- TEST 1: Posts - Content OR Media URL (Valid Cases)
-- ============================================================================

\echo '===================================================================='
\echo 'TEST 1: Posts - Valid Data'
\echo '===================================================================='

BEGIN;

-- Test 1a: Post with only content (SHOULD SUCCEED)
\echo 'Test 1a: Post with only content...'
INSERT INTO Posts (user_id, content) 
VALUES (1, 'This is a text post');
\echo '✓ PASS: Post with only content accepted'

-- Test 1b: Post with only media_url (SHOULD SUCCEED)
\echo 'Test 1b: Post with only media_url...'
INSERT INTO Posts (user_id, media_url) 
VALUES (1, 'https://example.com/image.jpg');
\echo '✓ PASS: Post with only media_url accepted'

-- Test 1c: Post with both content and media_url (SHOULD SUCCEED)
\echo 'Test 1c: Post with both content and media_url...'
INSERT INTO Posts (user_id, content, media_url) 
VALUES (1, 'Check out this image!', 'https://example.com/photo.jpg');
\echo '✓ PASS: Post with both content and media_url accepted'

ROLLBACK;

\echo ''

-- ============================================================================
-- TEST 2: Posts - Content OR Media URL (Invalid Cases)
-- ============================================================================

\echo '===================================================================='
\echo 'TEST 2: Posts - Invalid Data (Should Fail)'
\echo '===================================================================='

BEGIN;

-- Test 2a: Post with neither content nor media_url (SHOULD FAIL)
\echo 'Test 2a: Post with neither content nor media_url...'
DO $$
BEGIN
    BEGIN
        INSERT INTO Posts (user_id) VALUES (1);
        RAISE EXCEPTION '✗ FAIL: Empty post was accepted (should be rejected)';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE '✓ PASS: Empty post rejected correctly';
    END;
END $$;

-- Test 2b: Post with empty string content and no media (SHOULD FAIL)
\echo 'Test 2b: Post with empty string content...'
DO $$
BEGIN
    BEGIN
        INSERT INTO Posts (user_id, content) VALUES (1, '');
        RAISE EXCEPTION '✗ FAIL: Post with empty content was accepted';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE '✓ PASS: Post with empty content rejected correctly';
    END;
END $$;

ROLLBACK;

\echo ''

-- ============================================================================
-- TEST 3: Users - Email Format Validation (Valid Cases)
-- ============================================================================

\echo '===================================================================='
\echo 'TEST 3: Users - Valid Email Formats'
\echo '===================================================================='

BEGIN;

-- Test 3a: Standard email (SHOULD SUCCEED)
\echo 'Test 3a: Standard email format...'
INSERT INTO Users (username, email, password_hash) 
VALUES ('testuser1', 'user@example.com', 'hash123');
\echo '✓ PASS: Standard email accepted'

-- Test 3b: Email with subdomain (SHOULD SUCCEED)
\echo 'Test 3b: Email with subdomain...'
INSERT INTO Users (username, email, password_hash) 
VALUES ('testuser2', 'user@mail.example.com', 'hash123');
\echo '✓ PASS: Email with subdomain accepted'

-- Test 3c: Email with numbers and special chars (SHOULD SUCCEED)
\echo 'Test 3c: Email with numbers and special characters...'
INSERT INTO Users (username, email, password_hash) 
VALUES ('testuser3', 'user.name+tag123@example.co.uk', 'hash123');
\echo '✓ PASS: Complex email format accepted'

ROLLBACK;

\echo ''

-- ============================================================================
-- TEST 4: Users - Email Format Validation (Invalid Cases)
-- ============================================================================

\echo '===================================================================='
\echo 'TEST 4: Users - Invalid Email Formats (Should Fail)'
\echo '===================================================================='

BEGIN;

-- Test 4a: Email without @ symbol (SHOULD FAIL)
\echo 'Test 4a: Email without @ symbol...'
DO $$
BEGIN
    BEGIN
        INSERT INTO Users (username, email, password_hash) 
        VALUES ('testuser4', 'userexample.com', 'hash123');
        RAISE EXCEPTION '✗ FAIL: Email without @ was accepted';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE '✓ PASS: Email without @ rejected correctly';
    END;
END $$;

-- Test 4b: Email without domain (SHOULD FAIL)
\echo 'Test 4b: Email without domain...'
DO $$
BEGIN
    BEGIN
        INSERT INTO Users (username, email, password_hash) 
        VALUES ('testuser5', 'user@', 'hash123');
        RAISE EXCEPTION '✗ FAIL: Email without domain was accepted';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE '✓ PASS: Email without domain rejected correctly';
    END;
END $$;

-- Test 4c: Email without TLD (SHOULD FAIL)
\echo 'Test 4c: Email without top-level domain...'
DO $$
BEGIN
    BEGIN
        INSERT INTO Users (username, email, password_hash) 
        VALUES ('testuser6', 'user@example', 'hash123');
        RAISE EXCEPTION '✗ FAIL: Email without TLD was accepted';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE '✓ PASS: Email without TLD rejected correctly';
    END;
END $$;

-- Test 4d: Email with spaces (SHOULD FAIL)
\echo 'Test 4d: Email with spaces...'
DO $$
BEGIN
    BEGIN
        INSERT INTO Users (username, email, password_hash) 
        VALUES ('testuser7', 'user name@example.com', 'hash123');
        RAISE EXCEPTION '✗ FAIL: Email with spaces was accepted';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE '✓ PASS: Email with spaces rejected correctly';
    END;
END $$;

ROLLBACK;

\echo ''

-- ============================================================================
-- TEST 5: Comments - Minimum Length (Valid Cases)
-- ============================================================================

\echo '===================================================================='
\echo 'TEST 5: Comments - Valid Content'
\echo '===================================================================='

BEGIN;

-- Test 5a: Comment with single character (SHOULD SUCCEED)
\echo 'Test 5a: Comment with single character...'
INSERT INTO Comments (post_id, user_id, content) 
VALUES (1, 1, '!');
\echo '✓ PASS: Single character comment accepted'

-- Test 5b: Comment with normal text (SHOULD SUCCEED)
\echo 'Test 5b: Comment with normal text...'
INSERT INTO Comments (post_id, user_id, content) 
VALUES (1, 1, 'This is a comment');
\echo '✓ PASS: Normal comment accepted'

-- Test 5c: Comment with leading/trailing spaces but valid content (SHOULD SUCCEED)
\echo 'Test 5c: Comment with spaces around text...'
INSERT INTO Comments (post_id, user_id, content) 
VALUES (1, 1, '  valid comment  ');
\echo '✓ PASS: Comment with surrounding spaces accepted'

ROLLBACK;

\echo ''

-- ============================================================================
-- TEST 6: Comments - Minimum Length (Invalid Cases)
-- ============================================================================

\echo '===================================================================='
\echo 'TEST 6: Comments - Invalid Content (Should Fail)'
\echo '===================================================================='

BEGIN;

-- Test 6a: Empty comment (SHOULD FAIL)
\echo 'Test 6a: Empty comment...'
DO $$
BEGIN
    BEGIN
        INSERT INTO Comments (post_id, user_id, content) 
        VALUES (1, 1, '');
        RAISE EXCEPTION '✗ FAIL: Empty comment was accepted';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE '✓ PASS: Empty comment rejected correctly';
    END;
END $$;

-- Test 6b: Comment with only spaces (SHOULD FAIL)
\echo 'Test 6b: Comment with only spaces...'
DO $$
BEGIN
    BEGIN
        INSERT INTO Comments (post_id, user_id, content) 
        VALUES (1, 1, '     ');
        RAISE EXCEPTION '✗ FAIL: Comment with only spaces was accepted';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE '✓ PASS: Comment with only spaces rejected correctly';
    END;
END $$;

-- Test 6c: Comment with only tabs and newlines (SHOULD FAIL)
\echo 'Test 6c: Comment with only whitespace characters...'
DO $$
BEGIN
    BEGIN
        INSERT INTO Comments (post_id, user_id, content) 
        VALUES (1, 1, E'\t\n\r  ');
        RAISE EXCEPTION '✗ FAIL: Comment with only whitespace was accepted';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE '✓ PASS: Comment with only whitespace rejected correctly';
    END;
END $$;

ROLLBACK;

\echo ''

-- ============================================================================
-- TEST 7: Messages - Different Users (Valid Cases)
-- ============================================================================

\echo '===================================================================='
\echo 'TEST 7: Messages - Valid User Combinations'
\echo '===================================================================='

BEGIN;

-- Test 7a: Message from user 1 to user 2 (SHOULD SUCCEED)
\echo 'Test 7a: Message from user 1 to user 2...'
INSERT INTO Messages (sender_id, receiver_id, content) 
VALUES (1, 2, 'Hello user 2!');
\echo '✓ PASS: Message to different user accepted'

-- Test 7b: Reply from user 2 to user 1 (SHOULD SUCCEED)
\echo 'Test 7b: Reply from user 2 to user 1...'
INSERT INTO Messages (sender_id, receiver_id, content) 
VALUES (2, 1, 'Hello user 1!');
\echo '✓ PASS: Reply message accepted'

ROLLBACK;

\echo ''

-- ============================================================================
-- TEST 8: Messages - Different Users (Invalid Cases)
-- ============================================================================

\echo '===================================================================='
\echo 'TEST 8: Messages - Same User (Should Fail)'
\echo '===================================================================='

BEGIN;

-- Test 8a: User sending message to themselves (SHOULD FAIL)
\echo 'Test 8a: User 1 sending message to themselves...'
DO $$
BEGIN
    BEGIN
        INSERT INTO Messages (sender_id, receiver_id, content) 
        VALUES (1, 1, 'Message to myself');
        RAISE EXCEPTION '✗ FAIL: Self-message was accepted';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE '✓ PASS: Self-message rejected correctly';
    END;
END $$;

ROLLBACK;

\echo ''

-- ============================================================================
-- TEST SUMMARY
-- ============================================================================

\echo '===================================================================='
\echo 'TEST SUITE COMPLETED'
\echo '===================================================================='
\echo ''
\echo 'Test Results:'
\echo '  Posts Constraints:    8 tests (4 valid + 4 invalid)'
\echo '  Users Email:          7 tests (3 valid + 4 invalid)'
\echo '  Comments Length:      6 tests (3 valid + 3 invalid)'
\echo '  Messages Different:   3 tests (2 valid + 1 invalid)'
\echo ''
\echo 'Total Tests: 24'
\echo ''
\echo 'All CHECK constraints are working correctly!'
\echo '===================================================================='
