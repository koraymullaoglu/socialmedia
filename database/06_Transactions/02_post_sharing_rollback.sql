-- Transaction Example 2: Post Sharing with Follower Notifications
-- Demonstrates ROLLBACK behavior when part of transaction fails
-- Tests transaction consistency and error handling

\echo '========================================='
\echo 'TRANSACTION EXAMPLE 2: POST SHARING WITH NOTIFICATIONS'
\echo '========================================='

-- =====================================================
-- First, create a notifications table if it doesn't exist
-- =====================================================

CREATE TABLE IF NOT EXISTS Notifications (
    notification_id SERIAL PRIMARY KEY,
    user_id INT REFERENCES Users(user_id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    content TEXT NOT NULL,
    related_post_id INT REFERENCES Posts(post_id) ON DELETE CASCADE,
    related_user_id INT REFERENCES Users(user_id) ON DELETE SET NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

\echo '✓ Notifications table ready'

-- =====================================================
-- Function: share_post_and_notify_followers
-- Creates a post and notifies all followers
-- ROLLBACK test: If notification fails, entire transaction rolls back
-- =====================================================

CREATE OR REPLACE FUNCTION share_post_and_notify_followers(
    p_user_id INT,
    p_content TEXT,
    p_media_url TEXT DEFAULT NULL,
    p_community_id INT DEFAULT NULL,
    p_should_fail BOOLEAN DEFAULT FALSE  -- For testing rollback
)
RETURNS TABLE (
    post_id INT,
    user_id INT,
    content TEXT,
    notifications_sent INT,
    status VARCHAR(20)
) AS $$
DECLARE
    v_post_id INT;
    v_follower_count INT;
    v_notifications_created INT := 0;
BEGIN
    -- Step 1: Create the post
    INSERT INTO Posts (user_id, content, media_url, community_id)
    VALUES (p_user_id, p_content, p_media_url, p_community_id)
    RETURNING Posts.post_id INTO v_post_id;
    
    RAISE NOTICE 'Step 1: Post created with ID: %', v_post_id;
    
    -- Step 2: Get follower count
    SELECT COUNT(*) INTO v_follower_count
    FROM Follows f
    WHERE f.following_id = p_user_id
      AND f.status_id = (SELECT status_id FROM FollowStatus WHERE status_name = 'accepted');
    
    RAISE NOTICE 'Step 2: Found % followers to notify', v_follower_count;
    
    -- Optional: Simulate failure for testing
    IF p_should_fail THEN
        RAISE EXCEPTION 'Simulated notification failure for testing ROLLBACK';
    END IF;
    
    -- Step 3: Create notifications for all followers
    INSERT INTO Notifications (user_id, type, content, related_post_id, related_user_id)
    SELECT 
        f.follower_id,
        'new_post',
        (SELECT u.username FROM Users u WHERE u.user_id = p_user_id) || ' shared a new post',
        v_post_id,
        p_user_id
    FROM Follows f
    WHERE f.following_id = p_user_id
      AND f.status_id = (SELECT status_id FROM FollowStatus WHERE status_name = 'accepted');
    
    GET DIAGNOSTICS v_notifications_created = ROW_COUNT;
    
    RAISE NOTICE 'Step 3: Created % notifications', v_notifications_created;
    
    -- Return success result
    RETURN QUERY
    SELECT 
        v_post_id,
        p_user_id,
        p_content,
        v_notifications_created,
        'success'::VARCHAR(20);
    
    RAISE NOTICE '--- Transaction Committed Successfully ---';
    
EXCEPTION
    WHEN OTHERS THEN
        -- Any error causes ROLLBACK of all changes
        RAISE NOTICE '--- Transaction Rolled Back ---';
        RAISE NOTICE 'Error: %', SQLERRM;
        RAISE NOTICE 'Result: Post was NOT created, notifications were NOT sent';
        RAISE;
END;
$$ LANGUAGE plpgsql;

\echo '✓ Function share_post_and_notify_followers created'

-- =====================================================
-- Manual Transaction with Explicit ROLLBACK
-- Demonstrates how to manually control transaction flow
-- =====================================================

\echo ''
\echo 'Creating manual rollback example...'

CREATE OR REPLACE FUNCTION share_post_with_validation(
    p_user_id INT,
    p_content TEXT,
    p_max_notifications INT DEFAULT 1000  -- Safety limit
)
RETURNS TABLE (
    success BOOLEAN,
    post_id INT,
    message TEXT
) AS $$
DECLARE
    v_post_id INT;
    v_follower_count INT;
BEGIN
    -- Check follower count first
    SELECT COUNT(*) INTO v_follower_count
    FROM Follows
    WHERE following_id = p_user_id
      AND status_id = (SELECT status_id FROM FollowStatus WHERE status_name = 'accepted');
    
    -- Validate before starting main operations
    IF v_follower_count > p_max_notifications THEN
        -- Return error without creating anything
        RETURN QUERY SELECT 
            FALSE,
            NULL::INT,
            format('Too many followers (%s). Maximum allowed: %s', 
                   v_follower_count, p_max_notifications);
        RETURN;
    END IF;
    
    -- Proceed with transaction
    INSERT INTO Posts (user_id, content)
    VALUES (p_user_id, p_content)
    RETURNING Posts.post_id INTO v_post_id;
    
    -- Create notifications
    INSERT INTO Notifications (user_id, type, content, related_post_id, related_user_id)
    SELECT 
        f.follower_id,
        'new_post',
        'New post notification',
        v_post_id,
        p_user_id
    FROM Follows f
    WHERE f.following_id = p_user_id
      AND f.status_id = (SELECT status_id FROM FollowStatus WHERE status_name = 'accepted');
    
    -- Return success
    RETURN QUERY SELECT 
        TRUE,
        v_post_id,
        format('Post created and %s notifications sent', v_follower_count);
    
END;
$$ LANGUAGE plpgsql;

\echo '✓ Function share_post_with_validation created'

-- =====================================================
-- Demonstration: Explicit BEGIN/COMMIT/ROLLBACK
-- =====================================================

\echo ''
\echo 'Manual transaction control example:'

DO $$
DECLARE
    v_test_user_id INT;
    v_post_id INT;
BEGIN
    -- Get a test user
    SELECT user_id INTO v_test_user_id FROM Users LIMIT 1;
    
    IF v_test_user_id IS NULL THEN
        RAISE NOTICE 'No users found. Skipping demo.';
        RETURN;
    END IF;
    
    RAISE NOTICE '=== Demonstrating Explicit Transaction Control ===';
    RAISE NOTICE '';
    
    -- Example 1: Successful transaction
    BEGIN
        RAISE NOTICE 'Transaction 1: SUCCESS CASE';
        RAISE NOTICE '  - Creating post...';
        
        INSERT INTO Posts (user_id, content)
        VALUES (v_test_user_id, 'This post will be committed')
        RETURNING post_id INTO v_post_id;
        
        RAISE NOTICE '  - Post created with ID: %', v_post_id;
        RAISE NOTICE '  - Transaction committed!';
        RAISE NOTICE '';
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '  - Error occurred, rolling back...';
    END;
    
    -- Example 2: Failed transaction (simulated)
    BEGIN
        RAISE NOTICE 'Transaction 2: ROLLBACK CASE (simulated)';
        RAISE NOTICE '  - Would create post...';
        RAISE NOTICE '  - Would send notifications...';
        RAISE NOTICE '  - Error occurs in notification step!';
        RAISE NOTICE '  - ROLLBACK: Post is not created, notifications not sent';
        RAISE NOTICE '  - Database state remains unchanged';
        
    END;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== Demo Complete ===';
END $$;

\echo ''
\echo '========================================='
\echo 'Example Usage:'
\echo ''
\echo '-- Success case:'
\echo '  SELECT * FROM share_post_and_notify_followers(1, ''Hello World!'', NULL, NULL, FALSE);'
\echo ''
\echo '-- Failure case (tests rollback):'
\echo '  SELECT * FROM share_post_and_notify_followers(1, ''Test'', NULL, NULL, TRUE);'
\echo ''
\echo '-- With validation:'
\echo '  SELECT * FROM share_post_with_validation(1, ''New post'', 100);'
\echo ''
\echo 'Key Points:'
\echo '  - If notification fails, post is also rolled back'
\echo '  - Database maintains consistency'
\echo '  - All-or-nothing execution (ATOMICITY)'
\echo '========================================='
