-- Transaction Example 3: Nested Transactions with SAVEPOINT
-- Demonstrates partial rollback using SAVEPOINTs
-- Allows rolling back to a specific point without losing entire transaction

\echo '========================================='
\echo 'TRANSACTION EXAMPLE 3: SAVEPOINTS (NESTED TRANSACTIONS)'
\echo '========================================='

-- =====================================================
-- Function: batch_create_posts_with_savepoints
-- Creates multiple posts, using SAVEPOINT to handle individual failures
-- Some posts may succeed while others fail (partial rollback)
-- =====================================================

CREATE OR REPLACE FUNCTION batch_create_posts_with_savepoints(
    p_user_id INT,
    p_posts TEXT[],  -- Array of post contents
    p_continue_on_error BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
    post_number INT,
    post_id INT,
    content TEXT,
    status VARCHAR(20),
    error_message TEXT
) AS $$
DECLARE
    v_post_content TEXT;
    v_post_id INT;
    v_counter INT := 0;
    v_savepoint_name TEXT;
BEGIN
    RAISE NOTICE '=== Starting Batch Post Creation ===';
    RAISE NOTICE 'Total posts to create: %', array_length(p_posts, 1);
    RAISE NOTICE '';
    
    -- Loop through each post
    FOREACH v_post_content IN ARRAY p_posts
    LOOP
        v_counter := v_counter + 1;
        v_savepoint_name := 'post_' || v_counter;
        
        BEGIN
            -- Use exception block as implicit savepoint
            RAISE NOTICE 'Post %: Attempting to create...', v_counter;
            
            -- Validate content
            IF v_post_content IS NULL OR length(trim(v_post_content)) = 0 THEN
                RAISE EXCEPTION 'Post content cannot be empty';
            END IF;
            
            IF length(v_post_content) > 5000 THEN
                RAISE EXCEPTION 'Post content too long (max 5000 characters)';
            END IF;
            
            -- Create the post
            INSERT INTO Posts (user_id, content)
            VALUES (p_user_id, v_post_content)
            RETURNING Posts.post_id INTO v_post_id;
            
            RAISE NOTICE 'Post %: Created successfully with ID %', v_counter, v_post_id;
            
            -- Return success record
            RETURN QUERY SELECT 
                v_counter,
                v_post_id,
                v_post_content,
                'success'::VARCHAR(20),
                NULL::TEXT;
                
        EXCEPTION
            WHEN OTHERS THEN
                -- Exception block acts as implicit rollback for this operation
                RAISE NOTICE 'Post %: Failed - %', v_counter, SQLERRM;
                RAISE NOTICE 'Post %: Rolled back (other posts continue)', v_counter;
                
                -- Return error record
                RETURN QUERY SELECT 
                    v_counter,
                    NULL::INT,
                    v_post_content,
                    'failed'::VARCHAR(20),
                    SQLERRM;
                
                -- Re-raise exception if we're not continuing on errors
                IF NOT p_continue_on_error THEN
                    RAISE NOTICE 'Stopping batch due to error (continue_on_error = FALSE)';
                    RAISE;
                END IF;
        END;
        
        RAISE NOTICE '';
    END LOOP;
    
    RAISE NOTICE '=== Batch Creation Complete ===';
    
END;
$$ LANGUAGE plpgsql;

\echo '✓ Function batch_create_posts_with_savepoints created'

-- =====================================================
-- Function: create_community_with_multiple_members
-- Uses SAVEPOINT to add multiple members, continuing even if some fail
-- =====================================================

CREATE OR REPLACE FUNCTION create_community_with_multiple_members(
    p_creator_id INT,
    p_community_name VARCHAR(100),
    p_description TEXT,
    p_member_ids INT[]  -- Array of user IDs to add as members
)
RETURNS TABLE (
    operation VARCHAR(50),
    user_id INT,
    role_name VARCHAR(20),
    status VARCHAR(20),
    message TEXT
) AS $$
DECLARE
    v_community_id INT;
    v_admin_role_id INT;
    v_member_role_id INT;
    v_user_id INT;
    v_counter INT := 0;
BEGIN
    -- Get role IDs with explicit table aliases
    SELECT r.role_id INTO v_admin_role_id FROM Roles r WHERE r.role_name = 'admin';
    SELECT r.role_id INTO v_member_role_id FROM Roles r WHERE r.role_name = 'member';
    
    RAISE NOTICE '=== Creating Community with Multiple Members ===';
    
    -- Step 1: Create community (no savepoint, must succeed)
    INSERT INTO Communities (creator_id, name, description, privacy_id)
    VALUES (p_creator_id, p_community_name, p_description, 
            (SELECT privacy_id FROM PrivacyTypes WHERE privacy_name = 'public'))
    RETURNING community_id INTO v_community_id;
    
    RAISE NOTICE 'Community created with ID: %', v_community_id;
    
    -- Step 2: Add creator as admin (no savepoint, must succeed)
    INSERT INTO CommunityMembers (community_id, user_id, role_id)
    VALUES (v_community_id, p_creator_id, v_admin_role_id);
    
    RETURN QUERY SELECT 
        'create_community'::VARCHAR(50),
        p_creator_id,
        'admin'::VARCHAR(20),
        'success'::VARCHAR(20),
        format('Community "%s" created', p_community_name);
    
    RAISE NOTICE 'Creator added as admin';
    RAISE NOTICE '';
    
    -- Step 3: Add other members with exception blocks (partial failures OK)
    IF p_member_ids IS NOT NULL THEN
        FOREACH v_user_id IN ARRAY p_member_ids
        LOOP
            v_counter := v_counter + 1;
            
            BEGIN
                -- Use exception block as implicit savepoint
                
                -- Check if user exists
                IF NOT EXISTS (SELECT 1 FROM Users u WHERE u.user_id = v_user_id) THEN
                    RAISE EXCEPTION 'User ID % does not exist', v_user_id;
                END IF;
                
                -- Check if already a member
                IF EXISTS (
                    SELECT 1 FROM CommunityMembers cm
                    WHERE cm.community_id = v_community_id 
                      AND cm.user_id = v_user_id
                ) THEN
                    RAISE EXCEPTION 'User % is already a member', v_user_id;
                END IF;
                
                -- Add as member
                INSERT INTO CommunityMembers (community_id, user_id, role_id)
                VALUES (v_community_id, v_user_id, v_member_role_id);
                
                RAISE NOTICE 'Member %: User % added successfully', v_counter, v_user_id;
                
                RETURN QUERY SELECT 
                    'add_member'::VARCHAR(50),
                    v_user_id,
                    'member'::VARCHAR(20),
                    'success'::VARCHAR(20),
                    format('User %s added as member', v_user_id);
                    
            EXCEPTION
                WHEN OTHERS THEN
                    -- Exception block acts as implicit rollback
                    
                    RAISE NOTICE 'Member %: Failed to add user % - %', 
                        v_counter, v_user_id, SQLERRM;
                    
                    RETURN QUERY SELECT 
                        'add_member'::VARCHAR(50),
                        v_user_id,
                        'member'::VARCHAR(20),
                        'failed'::VARCHAR(20),
                        SQLERRM;
            END;
        END LOOP;
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== Community Creation Complete ===';
    RAISE NOTICE 'Community created: %', v_community_id;
    RAISE NOTICE 'Total members: %', 
        (SELECT COUNT(*) FROM CommunityMembers cm WHERE cm.community_id = v_community_id);
    
END;
$$ LANGUAGE plpgsql;

\echo '✓ Function create_community_with_multiple_members created'

-- =====================================================
-- Demonstration: Manual SAVEPOINT usage
-- =====================================================

\echo ''
\echo 'Manual SAVEPOINT demonstration:'

DO $$
DECLARE
    v_test_user_id INT;
BEGIN
    SELECT user_id INTO v_test_user_id FROM Users LIMIT 1;
    
    IF v_test_user_id IS NULL THEN
        RAISE NOTICE 'No users found. Skipping demo.';
        RETURN;
    END IF;
    
    RAISE NOTICE '=== SAVEPOINT Demonstration ===';
    RAISE NOTICE '';
    
    -- Main transaction starts here
    RAISE NOTICE 'Starting main transaction...';
    
    -- Operation 1: This will succeed
    SAVEPOINT operation1;
    RAISE NOTICE '  [SAVEPOINT operation1] Creating first post...';
    INSERT INTO Posts (user_id, content) 
    VALUES (v_test_user_id, 'First post - will succeed');
    RAISE NOTICE '  First post created successfully';
    RELEASE SAVEPOINT operation1;
    
    -- Operation 2: This will fail but we'll catch it
    SAVEPOINT operation2;
    BEGIN
        RAISE NOTICE '  [SAVEPOINT operation2] Creating second post...';
        INSERT INTO Posts (user_id, content) 
        VALUES (v_test_user_id, 'Second post - will fail');
        
        -- Simulate an error
        RAISE EXCEPTION 'Simulated error in second post';
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO SAVEPOINT operation2;
            RAISE NOTICE '  Second post failed: %', SQLERRM;
            RAISE NOTICE '  Rolled back to SAVEPOINT operation2';
            RAISE NOTICE '  First post is still intact!';
    END;
    
    -- Operation 3: This will succeed
    SAVEPOINT operation3;
    RAISE NOTICE '  [SAVEPOINT operation3] Creating third post...';
    INSERT INTO Posts (user_id, content) 
    VALUES (v_test_user_id, 'Third post - will succeed');
    RAISE NOTICE '  Third post created successfully';
    RELEASE SAVEPOINT operation3;
    
    RAISE NOTICE '';
    RAISE NOTICE 'Main transaction commits with posts 1 and 3';
    RAISE NOTICE 'Post 2 was rolled back but others remained';
    RAISE NOTICE '';
    RAISE NOTICE '=== Demo Complete ===';
    
END $$;

\echo ''
\echo '========================================='
\echo 'Example Usage:'
\echo ''
\echo '-- Batch create posts with partial failure handling:'
\echo "  SELECT * FROM batch_create_posts_with_savepoints("
\echo "    1,"
\echo "    ARRAY['Post 1', 'Post 2', '', 'Post 4'],"  -- Post 3 is empty and will fail
\echo "    TRUE"
\echo "  );"
\echo ''
\echo '-- Create community and add multiple members:'
\echo "  SELECT * FROM create_community_with_multiple_members("
\echo "    1,"
\echo "    'Gaming Community',"
\echo "    'For gamers',"
\echo "    ARRAY[2, 3, 999, 5]"  -- User 999 doesn't exist, will be skipped
\echo "  );"
\echo ''
\echo 'Key Points:'
\echo '  - SAVEPOINT creates a sub-transaction'
\echo '  - Can rollback to SAVEPOINT without losing entire transaction'
\echo '  - Useful for batch operations where some failures are acceptable'
\echo '  - RELEASE SAVEPOINT commits the sub-transaction'
\echo '========================================='
