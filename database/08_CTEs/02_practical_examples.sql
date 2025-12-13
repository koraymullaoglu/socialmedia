-- ============================================================================
-- CTE Practical Examples & Use Cases
-- ============================================================================
-- Runnable examples demonstrating recursive and non-recursive CTEs
-- ============================================================================

-- ============================================================================
-- SETUP: Sample Data for Testing
-- ============================================================================

/*
-- Insert test data for comment threads
INSERT INTO Posts (user_id, content) VALUES
(1, 'Main post for testing nested comments');

-- Create nested comment structure:
-- Post -> Comment 1
--      -> Comment 1.1
--           -> Comment 1.1.1
--      -> Comment 1.2
-- Post -> Comment 2
--      -> Comment 2.1

INSERT INTO Comments (post_id, user_id, content, parent_comment_id) VALUES
(1, 2, 'Top level comment 1', NULL),           -- ID: 1
(1, 3, 'Reply to comment 1', 1),               -- ID: 2
(1, 4, 'Reply to reply (nested)', 2),          -- ID: 3
(1, 5, 'Another reply to comment 1', 1),       -- ID: 4
(1, 6, 'Top level comment 2', NULL),           -- ID: 5
(1, 7, 'Reply to comment 2', 5);               -- ID: 6

-- Create follow relationships for friend-of-friend testing
-- User 1 -> User 2, 3
-- User 2 -> User 4, 5
-- User 3 -> User 5, 6
-- This creates: User 1 has friends 2,3 and friends-of-friends 4,5,6

INSERT INTO Follows (follower_id, following_id, status_id) VALUES
(1, 2, 1), (1, 3, 1),
(2, 4, 1), (2, 5, 1),
(3, 5, 1), (3, 6, 1),
(4, 7, 1), (5, 8, 1);
*/


-- ============================================================================
-- EXAMPLE 1: Simple Recursive CTE - Number Sequence
-- ============================================================================

-- Generate numbers 1 to 10 using recursive CTE
WITH RECURSIVE number_sequence AS (
    -- Base case: Start with 1
    SELECT 1 AS n
    
    UNION ALL
    
    -- Recursive case: Add 1
    SELECT n + 1
    FROM number_sequence
    WHERE n < 10
)
SELECT n AS number FROM number_sequence;

/*
Expected Output:
 number
--------
      1
      2
      3
      ...
     10
*/


-- ============================================================================
-- EXAMPLE 2: Date Range Generation
-- ============================================================================

-- Generate all dates in the last 7 days
WITH RECURSIVE date_series AS (
    SELECT CURRENT_DATE - INTERVAL '7 days' AS date
    
    UNION ALL
    
    SELECT date + INTERVAL '1 day'
    FROM date_series
    WHERE date < CURRENT_DATE
)
SELECT 
    date,
    TO_CHAR(date, 'Day') AS day_name,
    CASE 
        WHEN EXTRACT(DOW FROM date) IN (0, 6) THEN 'Weekend'
        ELSE 'Weekday'
    END AS day_type
FROM date_series
ORDER BY date;


-- ============================================================================
-- EXAMPLE 3: Display Comment Thread (Indented)
-- ============================================================================

WITH RECURSIVE comment_tree AS (
    -- Root comments
    SELECT 
        comment_id,
        parent_comment_id,
        user_id,
        content,
        created_at,
        0 AS level,
        ARRAY[comment_id] AS path
    FROM Comments
    WHERE post_id = 1 AND parent_comment_id IS NULL
    
    UNION ALL
    
    -- Child comments
    SELECT 
        c.comment_id,
        c.parent_comment_id,
        c.user_id,
        c.content,
        c.created_at,
        ct.level + 1,
        ct.path || c.comment_id
    FROM Comments c
    INNER JOIN comment_tree ct ON c.parent_comment_id = ct.comment_id
    WHERE ct.level < 10
)
SELECT 
    REPEAT('  ', level) || '└─ ' AS indent,
    u.username,
    ct.content,
    ct.level AS depth,
    TO_CHAR(ct.created_at, 'YYYY-MM-DD HH24:MI') AS posted_at
FROM comment_tree ct
INNER JOIN Users u ON ct.user_id = u.user_id
ORDER BY path;

/*
Expected Output:
 indent | username | content                  | depth | posted_at
--------+----------+--------------------------+-------+------------------
 └─     | alice    | Top level comment 1      |     0 | 2024-01-15 10:00
   └─   | bob      | Reply to comment 1       |     1 | 2024-01-15 10:30
     └─ | charlie  | Reply to reply (nested)  |     2 | 2024-01-15 11:00
   └─   | diana    | Another reply            |     1 | 2024-01-15 12:00
 └─     | eve      | Top level comment 2      |     0 | 2024-01-15 14:00
   └─   | frank    | Reply to comment 2       |     1 | 2024-01-15 15:00
*/


-- ============================================================================
-- EXAMPLE 4: Count Replies at Each Level
-- ============================================================================

WITH RECURSIVE comment_tree AS (
    SELECT 
        comment_id,
        parent_comment_id,
        0 AS level
    FROM Comments
    WHERE post_id = 1 AND parent_comment_id IS NULL
    
    UNION ALL
    
    SELECT 
        c.comment_id,
        c.parent_comment_id,
        ct.level + 1
    FROM Comments c
    INNER JOIN comment_tree ct ON c.parent_comment_id = ct.comment_id
)
SELECT 
    level,
    COUNT(*) AS comment_count,
    CASE 
        WHEN level = 0 THEN 'Top-level comments'
        WHEN level = 1 THEN 'Direct replies'
        WHEN level = 2 THEN 'Nested replies'
        ELSE 'Deep replies (level ' || level || ')'
    END AS level_description
FROM comment_tree
GROUP BY level
ORDER BY level;


-- ============================================================================
-- EXAMPLE 5: Find Comment Thread Participants
-- ============================================================================

-- Find all users who participated in a specific comment thread
WITH RECURSIVE comment_thread AS (
    -- Start with a specific comment
    SELECT comment_id, user_id, parent_comment_id
    FROM Comments
    WHERE comment_id = 3  -- Starting comment
    
    UNION
    
    -- Get all parent comments
    SELECT c.comment_id, c.user_id, c.parent_comment_id
    FROM Comments c
    INNER JOIN comment_thread ct ON c.comment_id = ct.parent_comment_id
    
    UNION
    
    -- Get all child comments
    SELECT c.comment_id, c.user_id, c.parent_comment_id
    FROM Comments c
    INNER JOIN comment_thread ct ON c.parent_comment_id = ct.comment_id
)
SELECT DISTINCT
    u.user_id,
    u.username,
    COUNT(ct.comment_id) AS comments_in_thread
FROM comment_thread ct
INNER JOIN Users u ON ct.user_id = u.user_id
GROUP BY u.user_id, u.username
ORDER BY comments_in_thread DESC;


-- ============================================================================
-- EXAMPLE 6: Friend-of-Friend Simple Example
-- ============================================================================

-- Find potential friends through mutual connections
WITH 
my_friends AS (
    SELECT following_id AS friend_id
    FROM Follows
    WHERE follower_id = 1 AND status_id = 1
),
friends_of_my_friends AS (
    SELECT DISTINCT f.following_id AS potential_friend
    FROM my_friends mf
    INNER JOIN Follows f ON f.follower_id = mf.friend_id
    WHERE f.status_id = 1
      AND f.following_id != 1  -- Not me
      AND f.following_id NOT IN (SELECT friend_id FROM my_friends)  -- Not already friends
)
SELECT 
    u.user_id,
    u.username,
    (
        SELECT COUNT(*)
        FROM my_friends mf
        INNER JOIN Follows f ON f.follower_id = mf.friend_id
        WHERE f.following_id = u.user_id AND f.status_id = 1
    ) AS mutual_friends_count
FROM friends_of_my_friends fof
INNER JOIN Users u ON u.user_id = fof.potential_friend
ORDER BY mutual_friends_count DESC;


-- ============================================================================
-- EXAMPLE 7: Social Network Degrees of Separation
-- ============================================================================

-- Find how many "hops" between two users
WITH RECURSIVE connection_path AS (
    -- Direct connections (1 hop)
    SELECT 
        1 AS user_from,
        following_id AS user_to,
        1 AS hops,
        ARRAY[1, following_id] AS path,
        ARRAY[following_id] AS visited
    FROM Follows
    WHERE follower_id = 1 AND status_id = 1
    
    UNION ALL
    
    -- Extended connections (2+ hops)
    SELECT 
        cp.user_from,
        f.following_id,
        cp.hops + 1,
        cp.path || f.following_id,
        cp.visited || f.following_id
    FROM connection_path cp
    INNER JOIN Follows f ON f.follower_id = cp.user_to
    WHERE f.status_id = 1
      AND cp.hops < 6  -- Maximum 6 degrees
      AND NOT (f.following_id = ANY(cp.visited))  -- Prevent cycles
)
SELECT 
    cp.user_from AS from_user_id,
    u1.username AS from_username,
    cp.user_to AS to_user_id,
    u2.username AS to_username,
    MIN(cp.hops) AS degrees_of_separation,
    (
        SELECT STRING_AGG(u.username, ' → ')
        FROM UNNEST((
            SELECT path 
            FROM connection_path 
            WHERE user_from = cp.user_from 
              AND user_to = cp.user_to 
            ORDER BY hops 
            LIMIT 1
        )) WITH ORDINALITY AS p(user_id, idx)
        INNER JOIN Users u ON u.user_id = p.user_id
    ) AS connection_chain
FROM connection_path cp
INNER JOIN Users u1 ON u1.user_id = cp.user_from
INNER JOIN Users u2 ON u2.user_id = cp.user_to
GROUP BY cp.user_from, u1.username, cp.user_to, u2.username
ORDER BY degrees_of_separation, to_username;


-- ============================================================================
-- EXAMPLE 8: Organizational Hierarchy (Works for any hierarchy)
-- ============================================================================

-- Assuming you have a manager_id field in Users table
-- This example shows how to traverse any parent-child relationship

WITH RECURSIVE org_chart AS (
    -- Top level (no manager)
    SELECT 
        user_id,
        username,
        NULL::INT AS manager_id,
        0 AS level,
        username AS hierarchy_path
    FROM Users
    WHERE user_id = 1  -- CEO or top-level user
    
    UNION ALL
    
    -- Subordinates
    SELECT 
        u.user_id,
        u.username,
        oc.user_id AS manager_id,
        oc.level + 1,
        oc.hierarchy_path || ' > ' || u.username
    FROM Users u
    INNER JOIN org_chart oc ON u.user_id = oc.user_id  -- Adjust join condition
    WHERE oc.level < 5
)
SELECT 
    REPEAT('  ', level) || username AS org_structure,
    level AS management_level,
    hierarchy_path
FROM org_chart
ORDER BY hierarchy_path;


-- ============================================================================
-- EXAMPLE 9: Category Tree (Blog Categories, Product Categories, etc.)
-- ============================================================================

-- If you have a categories table with parent_category_id
/*
WITH RECURSIVE category_tree AS (
    -- Root categories
    SELECT 
        category_id,
        category_name,
        parent_category_id,
        0 AS depth,
        category_name AS full_path
    FROM Categories
    WHERE parent_category_id IS NULL
    
    UNION ALL
    
    -- Sub-categories
    SELECT 
        c.category_id,
        c.category_name,
        c.parent_category_id,
        ct.depth + 1,
        ct.full_path || ' / ' || c.category_name
    FROM Categories c
    INNER JOIN category_tree ct ON c.parent_category_id = ct.category_id
)
SELECT 
    category_id,
    REPEAT('  ', depth) || category_name AS category_tree,
    full_path,
    depth
FROM category_tree
ORDER BY full_path;
*/


-- ============================================================================
-- EXAMPLE 10: Performance Test - CTE vs Subquery
-- ============================================================================

-- Scenario: Find users with high engagement

-- Method A: Using CTE (more readable)
EXPLAIN ANALYZE
WITH user_activity AS (
    SELECT 
        u.user_id,
        u.username,
        COUNT(DISTINCT p.post_id) AS posts,
        COUNT(DISTINCT c.comment_id) AS comments
    FROM Users u
    LEFT JOIN Posts p ON u.user_id = p.user_id
    LEFT JOIN Comments c ON u.user_id = c.user_id
    GROUP BY u.user_id, u.username
),
high_activity_users AS (
    SELECT *
    FROM user_activity
    WHERE posts > 5 OR comments > 10
)
SELECT * FROM high_activity_users
ORDER BY (posts + comments) DESC
LIMIT 20;


-- Method B: Using Subquery (less readable)
EXPLAIN ANALYZE
SELECT *
FROM (
    SELECT 
        u.user_id,
        u.username,
        COUNT(DISTINCT p.post_id) AS posts,
        COUNT(DISTINCT c.comment_id) AS comments
    FROM Users u
    LEFT JOIN Posts p ON u.user_id = p.user_id
    LEFT JOIN Comments c ON u.user_id = c.user_id
    GROUP BY u.user_id, u.username
) user_activity
WHERE posts > 5 OR comments > 10
ORDER BY (posts + comments) DESC
LIMIT 20;

-- Compare execution plans and timing!


-- ============================================================================
-- EXAMPLE 11: Multiple CTEs in Single Query
-- ============================================================================

-- Comprehensive user report using multiple CTEs
WITH 
user_posts AS (
    SELECT user_id, COUNT(*) AS post_count
    FROM Posts
    WHERE deleted_at IS NULL
    GROUP BY user_id
),
user_comments AS (
    SELECT user_id, COUNT(*) AS comment_count
    FROM Comments
    GROUP BY user_id
),
user_likes_received AS (
    SELECT p.user_id, COUNT(pl.like_id) AS likes_received
    FROM Posts p
    INNER JOIN Post_Likes pl ON p.post_id = pl.post_id
    GROUP BY p.user_id
),
user_followers AS (
    SELECT following_id AS user_id, COUNT(*) AS follower_count
    FROM Follows
    WHERE status_id = 1
    GROUP BY following_id
)
SELECT 
    u.user_id,
    u.username,
    COALESCE(up.post_count, 0) AS total_posts,
    COALESCE(uc.comment_count, 0) AS total_comments,
    COALESCE(ulr.likes_received, 0) AS total_likes,
    COALESCE(uf.follower_count, 0) AS total_followers,
    -- Calculate engagement score
    (COALESCE(up.post_count, 0) * 10 + 
     COALESCE(uc.comment_count, 0) * 5 + 
     COALESCE(ulr.likes_received, 0) * 2 +
     COALESCE(uf.follower_count, 0)) AS engagement_score
FROM Users u
LEFT JOIN user_posts up ON u.user_id = up.user_id
LEFT JOIN user_comments uc ON u.user_id = uc.user_id
LEFT JOIN user_likes_received ulr ON u.user_id = ulr.user_id
LEFT JOIN user_followers uf ON u.user_id = uf.user_id
ORDER BY engagement_score DESC
LIMIT 25;


-- ============================================================================
-- EXAMPLE 12: Recursive CTE with Aggregation
-- ============================================================================

-- Count total descendants for each comment
WITH RECURSIVE comment_descendants AS (
    SELECT 
        comment_id,
        parent_comment_id,
        comment_id AS root_comment,
        0 AS level
    FROM Comments
    WHERE post_id = 1
    
    UNION ALL
    
    SELECT 
        c.comment_id,
        c.parent_comment_id,
        cd.root_comment,
        cd.level + 1
    FROM Comments c
    INNER JOIN comment_descendants cd ON c.parent_comment_id = cd.comment_id
    WHERE cd.level < 10
)
SELECT 
    root_comment,
    u.username,
    c.content,
    COUNT(*) - 1 AS total_descendants,  -- Subtract 1 for the root itself
    MAX(level) AS max_depth
FROM comment_descendants cd
INNER JOIN Comments c ON c.comment_id = cd.root_comment
INNER JOIN Users u ON u.user_id = c.user_id
GROUP BY root_comment, u.username, c.content
ORDER BY total_descendants DESC;


-- ============================================================================
-- EXAMPLE 13: Circular Reference Detection
-- ============================================================================

-- Detect circular references in follow relationships
-- (Should not exist, but useful pattern for other hierarchies)

WITH RECURSIVE follow_chain AS (
    SELECT 
        follower_id,
        following_id,
        ARRAY[follower_id, following_id] AS path,
        FALSE AS has_cycle
    FROM Follows
    WHERE status_id = 1
    
    UNION ALL
    
    SELECT 
        fc.follower_id,
        f.following_id,
        fc.path || f.following_id,
        f.following_id = ANY(fc.path) AS has_cycle
    FROM follow_chain fc
    INNER JOIN Follows f ON f.follower_id = fc.following_id
    WHERE NOT fc.has_cycle
      AND ARRAY_LENGTH(fc.path, 1) < 10
)
SELECT 
    follower_id,
    following_id,
    path,
    ARRAY_LENGTH(path, 1) AS path_length
FROM follow_chain
WHERE has_cycle = TRUE;

-- If this returns rows, you have circular follows!


-- ============================================================================
-- EXAMPLE 14: Materialized CTE (PostgreSQL 12+)
-- ============================================================================

-- Force CTE materialization for multiple references
WITH popular_posts AS MATERIALIZED (
    SELECT 
        p.post_id,
        p.user_id,
        COUNT(pl.like_id) AS like_count
    FROM Posts p
    LEFT JOIN Post_Likes pl ON p.post_id = pl.post_id
    GROUP BY p.post_id, p.user_id
    HAVING COUNT(pl.like_id) > 10
)
SELECT 
    pp.post_id,
    u.username,
    pp.like_count,
    (SELECT COUNT(*) FROM Comments WHERE post_id = pp.post_id) AS comment_count,
    RANK() OVER (ORDER BY pp.like_count DESC) AS popularity_rank
FROM popular_posts pp
INNER JOIN Users u ON pp.user_id = u.user_id
ORDER BY pp.like_count DESC;


-- ============================================================================
-- EXAMPLE 15: Data Modification with CTE (DML in CTE)
-- ============================================================================

-- Delete old posts and return deleted count per user
WITH deleted_posts AS (
    DELETE FROM Posts
    WHERE created_at < NOW() - INTERVAL '365 days'
      AND deleted_at IS NULL
    RETURNING user_id, post_id
)
SELECT 
    u.username,
    COUNT(dp.post_id) AS posts_deleted
FROM deleted_posts dp
INNER JOIN Users u ON dp.user_id = u.user_id
GROUP BY u.username
ORDER BY posts_deleted DESC;

-- Note: Use with caution! This actually deletes data
