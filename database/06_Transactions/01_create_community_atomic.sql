-- Transaction Example 1: Atomic Community Creation
-- Creates a community and sets creator as admin in a single transaction
-- Demonstrates ATOMICITY: Either both operations succeed or both fail

\echo '========================================='
\echo 'TRANSACTION EXAMPLE 1: ATOMIC COMMUNITY CREATION'
\echo '========================================='

-- =====================================================
-- Function: create_community_with_admin
-- Creates community and assigns creator as admin atomically
-- =====================================================

CREATE OR REPLACE FUNCTION create_community_with_admin(
    p_creator_id INT,
    p_community_name VARCHAR(100),
    p_description TEXT,
    p_is_private BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
    community_id INT,
    creator_id INT,
    community_name VARCHAR(100),
    member_id INT,
    role_name VARCHAR(20),
    status VARCHAR(20)
) AS $$
DECLARE
    v_community_id INT;
    v_admin_role_id INT;
    v_privacy_id INT;
BEGIN
    -- Get admin role ID
    SELECT r.role_id INTO v_admin_role_id 
    FROM Roles r
    WHERE r.role_name = 'admin';
    
    IF v_admin_role_id IS NULL THEN
        RAISE EXCEPTION 'Admin role not found';
    END IF;
    
    -- Get privacy type
    SELECT privacy_id INTO v_privacy_id
    FROM PrivacyTypes
    WHERE privacy_name = CASE WHEN p_is_private THEN 'private' ELSE 'public' END;
    
    -- Start transaction (implicit in function)
    -- Step 1: Create the community
    INSERT INTO Communities (creator_id, name, description, privacy_id)
    VALUES (p_creator_id, p_community_name, p_description, v_privacy_id)
    RETURNING Communities.community_id INTO v_community_id;
    
    -- Step 2: Add creator as admin member
    INSERT INTO CommunityMembers (community_id, user_id, role_id)
    VALUES (v_community_id, p_creator_id, v_admin_role_id);
    
    -- Return the results
    RETURN QUERY
    SELECT 
        c.community_id,
        c.creator_id,
        c.name AS community_name,
        cm.user_id AS member_id,
        r.role_name,
        'success'::VARCHAR(20) AS status
    FROM Communities c
    JOIN CommunityMembers cm ON c.community_id = cm.community_id
    JOIN Roles r ON cm.role_id = r.role_id
    WHERE c.community_id = v_community_id;
    
    -- If we reach here, transaction will commit
    RAISE NOTICE 'Community created successfully with ID: %', v_community_id;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Any error will cause automatic ROLLBACK
        RAISE NOTICE 'Transaction failed: %', SQLERRM;
        RAISE;  -- Re-raise the exception
END;
$$ LANGUAGE plpgsql;

\echo '✓ Function create_community_with_admin created'

-- =====================================================
-- Manual Transaction Example
-- Same operation but written as explicit SQL transaction
-- =====================================================

\echo ''
\echo 'Creating manual transaction example...'

-- Example: Create a community manually with explicit transaction
DO $$
DECLARE
    v_test_user_id INT;
    v_new_community_id INT;
    v_admin_role_id INT;
BEGIN
    -- Get a test user
    SELECT user_id INTO v_test_user_id FROM Users LIMIT 1;
    
    IF v_test_user_id IS NULL THEN
        RAISE NOTICE 'No users found. Skipping manual transaction example.';
        RETURN;
    END IF;
    
    -- Get admin role
    SELECT r.role_id INTO v_admin_role_id FROM Roles r WHERE r.role_name = 'admin';
    
    -- BEGIN TRANSACTION (implicit in DO block)
    RAISE NOTICE '--- Starting Transaction ---';
    
    -- Step 1: Create community
    INSERT INTO Communities (creator_id, name, description, privacy_id)
    VALUES (v_test_user_id, 'Tech Enthusiasts', 'Community for technology lovers', 
            (SELECT privacy_id FROM PrivacyTypes WHERE privacy_name = 'public'))
    RETURNING community_id INTO v_new_community_id;
    
    RAISE NOTICE 'Community created with ID: %', v_new_community_id;
    
    -- Step 2: Add creator as admin
    INSERT INTO CommunityMembers (community_id, user_id, role_id)
    VALUES (v_new_community_id, v_test_user_id, v_admin_role_id);
    
    RAISE NOTICE 'Creator added as admin';
    RAISE NOTICE '--- Transaction Committed Successfully ---';
    
    -- Verify the results
    RAISE NOTICE 'Verification: Community "%" has % members', 
        (SELECT name FROM Communities WHERE community_id = v_new_community_id),
        (SELECT COUNT(*) FROM CommunityMembers WHERE community_id = v_new_community_id);
        
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '--- Transaction Rolled Back Due to Error ---';
        RAISE NOTICE 'Error: %', SQLERRM;
        RAISE;
END $$;

\echo ''
\echo '========================================='
\echo 'Example Usage:'
\echo '  SELECT * FROM create_community_with_admin(1, ''My Community'', ''Description'', FALSE);'
\echo ''
\echo 'Success Case: Both community and admin membership are created'
\echo 'Failure Case: If any step fails, entire transaction is rolled back'
\echo '========================================='
