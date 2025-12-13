-- ============================================================================
-- Window Functions - Practical Examples & Test Queries
-- ============================================================================
-- This file contains practical, runnable examples demonstrating window functions
-- with expected outputs and use cases
-- ============================================================================

-- ============================================================================
-- SETUP: Sample Data for Testing
-- ============================================================================
-- Before running tests, ensure you have sample data:

/*
-- Insert test users
INSERT INTO Users (username, email, password_hash) VALUES
('alice', 'alice@example.com', 'hash1'),
('bob', 'bob@example.com', 'hash2'),
('charlie', 'charlie@example.com', 'hash3');

-- Insert test posts
INSERT INTO Posts (user_id, content, created_at) VALUES
(1, 'First post by Alice', '2024-01-01 10:00'),
(1, 'Second post by Alice', '2024-01-02 14:30'),
(1, 'Third post by Alice', '2024-01-03 09:15'),
(2, 'Bob\'s first post', '2024-01-02 11:00'),
(2, 'Bob\'s second post', '2024-01-05 16:20'),
(3, 'Charlie is here', '2024-01-01 15:45');

-- Insert test likes
INSERT INTO Post_Likes (post_id, user_id) VALUES
(1, 2), (1, 3), (1, 1),
(2, 2), (2, 3),
(3, 1), (3, 2),
(4, 1), (4, 3),
(5, 1), (5, 2), (5, 3);
*/


-- ============================================================================
-- EXAMPLE 1: Basic ROW_NUMBER - Post Numbering
-- ============================================================================

-- Simple post numbering
SELECT
    u.username,
    p.post_id,
    p.content,
    p.created_at,
    ROW_NUMBER() OVER (
        PARTITION BY p.user_id
        ORDER BY p.created_at
    ) AS post_number
FROM Posts p
INNER JOIN Users u ON p.user_id = u.user_id
ORDER BY u.username, p.created_at;

/*
Expected Output:
| username | post_id | content | created_at | post_number |
|----------|---------|---------|------------|------------|
| alice | 1 | First post by Alice | 2024-01-01 | 1 |
| alice | 2 | Second post by Alice | 2024-01-02 | 2 |
| alice | 3 | Third post by Alice | 2024-01-03 | 3 |
| bob | 4 | Bob's first post | 2024-01-02 | 1 |
| bob | 5 | Bob's second post | 2024-01-05 | 2 |
| charlie | 6 | Charlie is here | 2024-01-01 | 1 |
*/

-- Example: Get only the latest 3 posts from each user
SELECT *
FROM (
    SELECT
        u.username,
        p.content,
        p.created_at,
        ROW_NUMBER() OVER (
            PARTITION BY p.user_id
            ORDER BY p.created_at DESC
        ) AS recency_rank
    FROM Posts p
    INNER JOIN Users u ON p.user_id = u.user_id
) ranked_posts
WHERE recency_rank <= 3;


-- ============================================================================
-- EXAMPLE 2: Running Totals with SUM and ROWS BETWEEN
-- ============================================================================

-- Daily post activity with running total
SELECT
    u.username,
    DATE(p.created_at) AS post_date,
    COUNT(*) AS daily_posts,
    SUM(COUNT(*)) OVER (
        PARTITION BY p.user_id
        ORDER BY DATE(p.created_at)
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_posts,
    -- Calculate day number
    ROW_NUMBER() OVER (
        PARTITION BY p.user_id
        ORDER BY DATE(p.created_at)
    ) AS active_day_number
FROM Posts p
INNER JOIN Users u ON p.user_id = u.user_id
GROUP BY u.username, DATE(p.created_at)
ORDER BY u.username, post_date;

/*
Expected Output:
| username | post_date | daily_posts | cumulative_posts | active_day_number |
|----------|-----------|-------------|------------------|------------------|
| alice | 2024-01-01 | 1 | 1 | 1 |
| alice | 2024-01-02 | 1 | 2 | 2 |
| alice | 2024-01-03 | 1 | 3 | 3 |
| bob | 2024-01-02 | 1 | 1 | 1 |
| bob | 2024-01-05 | 1 | 2 | 2 |
| charlie | 2024-01-01 | 1 | 1 | 1 |
*/

-- Example: Running average with moving window
SELECT
    u.username,
    p.post_id,
    DATE(p.created_at) AS post_date,
    COUNT(pl.like_id) AS likes,
    ROUND(
        AVG(COUNT(pl.like_id)) OVER (
            PARTITION BY p.user_id
            ORDER BY DATE(p.created_at)
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ),
        2
    ) AS moving_avg_likes_3day
FROM Posts p
LEFT JOIN Post_Likes pl ON p.post_id = pl.post_id
INNER JOIN Users u ON p.user_id = u.user_id
GROUP BY u.username, p.post_id, DATE(p.created_at);


-- ============================================================================
-- EXAMPLE 3: RANK vs DENSE_RANK
-- ============================================================================

-- Compare RANK and DENSE_RANK
SELECT
    u.username,
    COUNT(p.post_id) AS total_posts,
    RANK() OVER (
        ORDER BY COUNT(p.post_id) DESC
    ) AS rank_position,
    DENSE_RANK() OVER (
        ORDER BY COUNT(p.post_id) DESC
    ) AS dense_rank_position,
    ROUND(
        PERCENT_RANK() OVER (
            ORDER BY COUNT(p.post_id) DESC
        ) * 100,
        2
    ) AS percentile
FROM Users u
LEFT JOIN Posts p ON u.user_id = p.user_id
GROUP BY u.user_id, u.username
ORDER BY total_posts DESC;

/*
Expected Output (with ties):
| username | total_posts | rank | dense_rank | percentile |
|----------|-------------|------|-----------|------------|
| alice | 3 | 1 | 1 | 100.00 |
| bob | 2 | 2 | 2 | 66.67 |
| charlie | 1 | 3 | 3 | 33.33 |

If bob and alice both had 2 posts:
| alice | 2 | 1 | 1 | 100.00 |
| bob | 2 | 1 | 1 | 100.00 |
| charlie | 1 | 3 | 2 | 0.00 |  <- Note RANK skips to 3
*/

-- Top 10 users by activity (with ties handled by DENSE_RANK)
SELECT
    DENSE_RANK() OVER (
        ORDER BY COUNT(p.post_id) DESC
    ) AS activity_tier,
    u.username,
    COUNT(p.post_id) AS posts,
    CASE
        WHEN DENSE_RANK() OVER (ORDER BY COUNT(p.post_id) DESC) = 1
            THEN 'Elite'
        WHEN DENSE_RANK() OVER (ORDER BY COUNT(p.post_id) DESC) <= 5
            THEN 'Top Tier'
        WHEN DENSE_RANK() OVER (ORDER BY COUNT(p.post_id) DESC) <= 10
            THEN 'Active'
        ELSE 'Regular'
    END AS user_category
FROM Users u
LEFT JOIN Posts p ON u.user_id = p.user_id AND p.deleted_at IS NULL
GROUP BY u.user_id, u.username
ORDER BY activity_tier;


-- ============================================================================
-- EXAMPLE 4: LAG and LEAD - Post Comparison
-- ============================================================================

-- View posting gaps between consecutive posts
SELECT
    u.username,
    p.post_id,
    p.content,
    p.created_at,
    LAG(p.created_at) OVER (
        PARTITION BY p.user_id
        ORDER BY p.created_at
    ) AS previous_post_time,
    -- Calculate time difference in hours
    ROUND(
        EXTRACT(EPOCH FROM (
            p.created_at - LAG(p.created_at) OVER (
                PARTITION BY p.user_id
                ORDER BY p.created_at
            )
        )) / 3600,
        2
    ) AS hours_since_previous,
    LEAD(p.created_at) OVER (
        PARTITION BY p.user_id
        ORDER BY p.created_at
    ) AS next_post_time,
    ROUND(
        EXTRACT(EPOCH FROM (
            LEAD(p.created_at) OVER (
                PARTITION BY p.user_id
                ORDER BY p.created_at
            ) - p.created_at
        )) / 3600,
        2
    ) AS hours_until_next
FROM Posts p
INNER JOIN Users u ON p.user_id = u.user_id
ORDER BY u.username, p.created_at;

/*
Expected Output:
| username | post_id | content | created_at | prev_time | hours_since | next_time | hours_until |
|----------|---------|---------|------------|-----------|-------------|-----------|-------------|
| alice | 1 | First post | 2024-01-01 10:00 | NULL | NULL | 2024-01-02 14:30 | 28.50 |
| alice | 2 | Second post | 2024-01-02 14:30 | 2024-01-01 10:00 | 28.50 | 2024-01-03 09:15 | 18.75 |
| alice | 3 | Third post | 2024-01-03 09:15 | 2024-01-02 14:30 | 18.75 | NULL | NULL |
*/

-- Detect posting patterns
SELECT
    u.username,
    COUNT(CASE WHEN hours_since_previous < 24 THEN 1 END) AS posts_within_24h,
    COUNT(CASE WHEN hours_since_previous >= 24 AND hours_since_previous < 168 THEN 1 END) AS posts_within_week,
    COUNT(CASE WHEN hours_since_previous >= 168 THEN 1 END) AS posts_after_week,
    COUNT(CASE WHEN hours_since_previous IS NULL THEN 1 END) AS first_posts
FROM (
    SELECT
        u.user_id,
        u.username,
        ROUND(
            EXTRACT(EPOCH FROM (
                p.created_at - LAG(p.created_at) OVER (
                    PARTITION BY p.user_id
                    ORDER BY p.created_at
                )
            )) / 3600,
            2
        ) AS hours_since_previous
    FROM Posts p
    INNER JOIN Users u ON p.user_id = u.user_id
) post_gaps
GROUP BY u.username
ORDER BY u.username;


-- ============================================================================
-- EXAMPLE 5: Engagement Trend Analysis
-- ============================================================================

-- Track likes trend with previous comparison
SELECT
    u.username,
    p.post_id,
    p.created_at,
    current_likes.likes AS current_likes,
    LAG(current_likes.likes) OVER (
        PARTITION BY p.user_id
        ORDER BY p.created_at
    ) AS previous_post_likes,
    COALESCE(
        current_likes.likes - LAG(current_likes.likes) OVER (
            PARTITION BY p.user_id
            ORDER BY p.created_at
        ),
        0
    ) AS like_difference,
    ROUND(
        AVG(current_likes.likes) OVER (
            PARTITION BY p.user_id
            ORDER BY p.created_at
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ),
        2
    ) AS moving_avg_3posts
FROM Posts p
INNER JOIN Users u ON p.user_id = u.user_id
INNER JOIN (
    SELECT post_id, COUNT(*) AS likes
    FROM Post_Likes
    GROUP BY post_id
) current_likes ON p.post_id = current_likes.post_id
ORDER BY u.username, p.created_at;

/*
Expected Output:
| username | post_id | created_at | current_likes | prev_likes | difference | moving_avg |
|----------|---------|------------|---------------|-----------|-----------|-----------|
| alice | 1 | 2024-01-01 | 3 | NULL | 0 | 3.00 |
| alice | 2 | 2024-01-02 | 2 | 3 | -1 | 2.50 |
| alice | 3 | 2024-01-03 | 2 | 2 | 0 | 2.33 |
*/


-- ============================================================================
-- EXAMPLE 6: User Activity Classification
-- ============================================================================

-- Classify users by activity patterns
WITH user_stats AS (
    SELECT
        u.user_id,
        u.username,
        COUNT(p.post_id) AS total_posts,
        COUNT(pl.like_id) AS total_likes_received,
        MAX(p.created_at) AS last_post_date,
        MIN(p.created_at) AS first_post_date
    FROM Users u
    LEFT JOIN Posts p ON u.user_id = p.user_id AND p.deleted_at IS NULL
    LEFT JOIN Post_Likes pl ON p.post_id = pl.post_id
    GROUP BY u.user_id, u.username
)
SELECT
    DENSE_RANK() OVER (
        ORDER BY total_posts DESC
    ) AS activity_rank,
    username,
    total_posts,
    total_likes_received,
    CASE
        WHEN total_posts = 0 THEN 'Inactive'
        WHEN total_posts < 5 THEN 'Minimal'
        WHEN total_posts < 20 THEN 'Regular'
        WHEN total_posts < 50 THEN 'Active'
        ELSE 'Power User'
    END AS activity_level,
    CASE
        WHEN last_post_date >= NOW() - INTERVAL '7 days' THEN 'Active (This Week)'
        WHEN last_post_date >= NOW() - INTERVAL '30 days' THEN 'Active (This Month)'
        WHEN last_post_date IS NOT NULL THEN 'Inactive'
        ELSE 'Never Posted'
    END AS current_status,
    ROUND(
        total_likes_received::NUMERIC / NULLIF(total_posts, 0),
        2
    ) AS avg_likes_per_post
FROM user_stats
ORDER BY activity_rank;


-- ============================================================================
-- EXAMPLE 7: First/Last Value Functions
-- ============================================================================

-- Show first and last posts for each user
SELECT
    u.username,
    p.post_id,
    p.content,
    p.created_at,
    FIRST_VALUE(p.post_id) OVER (
        PARTITION BY p.user_id
        ORDER BY p.created_at
    ) AS first_post_id,
    FIRST_VALUE(p.created_at) OVER (
        PARTITION BY p.user_id
        ORDER BY p.created_at
    ) AS first_post_date,
    LAST_VALUE(p.post_id) OVER (
        PARTITION BY p.user_id
        ORDER BY p.created_at
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS last_post_id,
    LAST_VALUE(p.created_at) OVER (
        PARTITION BY p.user_id
        ORDER BY p.created_at
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS last_post_date
FROM Posts p
INNER JOIN Users u ON p.user_id = u.user_id
ORDER BY u.username, p.created_at;


-- ============================================================================
-- EXAMPLE 8: Cumulative Distribution (CUME_DIST)
-- ============================================================================

-- Show cumulative distribution of post counts
SELECT
    username,
    total_posts,
    ROUND(
        CUME_DIST() OVER (
            ORDER BY total_posts
        ) * 100,
        2
    ) AS percentile_position
FROM (
    SELECT
        u.username,
        COUNT(p.post_id) AS total_posts
    FROM Users u
    LEFT JOIN Posts p ON u.user_id = p.user_id
    GROUP BY u.user_id, u.username
) user_posts
ORDER BY total_posts DESC;

/*
CUME_DIST() shows the cumulative relative position
If 3 users have posts: 1, 2, 3 (sorted)
- 1 post: CUME_DIST = 0.33 (1 out of 3 users)
- 2 posts: CUME_DIST = 0.67 (2 out of 3 users)  
- 3 posts: CUME_DIST = 1.00 (all 3 users)
*/


-- ============================================================================
-- EXAMPLE 9: NTILE for Quartile Analysis
-- ============================================================================

-- Divide users into activity quartiles
SELECT
    NTILE(4) OVER (
        ORDER BY total_posts
    ) AS quartile,
    CASE
        WHEN NTILE(4) OVER (ORDER BY total_posts) = 1
            THEN 'Bottom 25% (Least Active)'
        WHEN NTILE(4) OVER (ORDER BY total_posts) = 2
            THEN 'Lower Middle 25%'
        WHEN NTILE(4) OVER (ORDER BY total_posts) = 3
            THEN 'Upper Middle 25%'
        ELSE 'Top 25% (Most Active)'
    END AS quartile_label,
    username,
    total_posts,
    COUNT(*) OVER (
        PARTITION BY NTILE(4) OVER (ORDER BY total_posts)
    ) AS users_in_quartile
FROM (
    SELECT
        u.username,
        COUNT(p.post_id) AS total_posts
    FROM Users u
    LEFT JOIN Posts p ON u.user_id = p.user_id
    GROUP BY u.user_id, u.username
) user_posts
ORDER BY total_posts DESC;


-- ============================================================================
-- EXAMPLE 10: Complex Window Analysis - Top Posts by Category
-- ============================================================================

-- Find most liked posts per user, with ranking
SELECT
    u.username,
    p.post_id,
    p.content,
    like_count,
    RANK() OVER (
        PARTITION BY p.user_id
        ORDER BY like_count DESC
    ) AS like_rank_for_user,
    PERCENT_RANK() OVER (
        PARTITION BY p.user_id
        ORDER BY like_count DESC
    ) AS like_percentile_within_user,
    DENSE_RANK() OVER (
        ORDER BY like_count DESC
    ) AS global_like_rank
FROM Posts p
INNER JOIN Users u ON p.user_id = u.user_id
INNER JOIN (
    SELECT post_id, COUNT(*) AS like_count
    FROM Post_Likes
    GROUP BY post_id
) post_likes ON p.post_id = post_likes.post_id
WHERE RANK() OVER (
    PARTITION BY p.user_id
    ORDER BY like_count DESC
) <= 3  -- Top 3 posts per user
ORDER BY u.username, like_rank_for_user;


-- ============================================================================
-- PERFORMANCE TIPS
-- ============================================================================

-- Create indexes for window function queries
CREATE INDEX IF NOT EXISTS idx_posts_user_created ON Posts(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_post_likes_post_id ON Post_Likes(post_id);
CREATE INDEX IF NOT EXISTS idx_users_id ON Users(user_id);

-- Use EXPLAIN to analyze window function queries
EXPLAIN ANALYZE
SELECT
    u.username,
    p.post_id,
    ROW_NUMBER() OVER (PARTITION BY p.user_id ORDER BY p.created_at) AS post_num
FROM Posts p
INNER JOIN Users u ON p.user_id = u.user_id;
