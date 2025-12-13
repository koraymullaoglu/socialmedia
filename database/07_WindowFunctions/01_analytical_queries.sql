-- ============================================================================
-- PostgreSQL Window Functions - Analytical Queries
-- ============================================================================
-- This module implements advanced analytics using window functions:
-- - ROW_NUMBER for chronological post numbering
-- - Running totals with SUM OVER
-- - RANK and DENSE_RANK for user activity rankings
-- - LAG/LEAD for post comparison and trends
-- ============================================================================

-- ============================================================================
-- 1. CHRONOLOGICAL NUMBERING OF USER POSTS (ROW_NUMBER)
-- ============================================================================
-- Assigns sequential numbers to each user's posts in chronological order

CREATE OR REPLACE VIEW user_post_sequence AS
SELECT
    user_id,
    post_id,
    content,
    created_at,
    -- Assign row numbers for each user's posts, ordered by creation date
    ROW_NUMBER() OVER (
        PARTITION BY user_id 
        ORDER BY created_at ASC
    ) AS post_sequence_number,
    -- Also show the reverse sequence (newest first)
    ROW_NUMBER() OVER (
        PARTITION BY user_id 
        ORDER BY created_at DESC
    ) AS post_reverse_sequence
FROM Posts
WHERE deleted_at IS NULL;

-- Query to display user's posts with sequence numbers
SELECT 
    u.username,
    ups.post_sequence_number,
    ups.content,
    ups.created_at,
    CASE 
        WHEN ups.post_sequence_number = 1 THEN 'First Post'
        WHEN ups.post_sequence_number = 2 THEN 'Second Post'
        ELSE ups.post_sequence_number || 'th Post'
    END AS position_description
FROM user_post_sequence ups
INNER JOIN Users u ON ups.user_id = u.user_id
ORDER BY u.username, ups.post_sequence_number;


-- ============================================================================
-- 2. RUNNING TOTAL OF DAILY POST COUNTS PER USER
-- ============================================================================
-- Shows cumulative count of posts for each user by day

CREATE OR REPLACE VIEW daily_post_cumulative AS
SELECT
    user_id,
    DATE(created_at) AS post_date,
    COUNT(*) OVER (
        PARTITION BY user_id
    ) AS total_posts_by_user,
    COUNT(*) AS daily_post_count,
    -- Running total: cumulative posts up to this day
    SUM(COUNT(*)) OVER (
        PARTITION BY user_id
        ORDER BY DATE(created_at)
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_posts,
    -- Daily average up to this point
    ROUND(
        SUM(COUNT(*)) OVER (
            PARTITION BY user_id
            ORDER BY DATE(created_at)
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )::NUMERIC / 
        (ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY DATE(created_at)
        )),
        2
    ) AS average_posts_per_day
FROM Posts
WHERE deleted_at IS NULL
GROUP BY user_id, DATE(created_at);

-- Query to display running totals with trends
SELECT
    u.username,
    dpc.post_date,
    dpc.daily_post_count,
    dpc.cumulative_posts,
    dpc.average_posts_per_day,
    dpc.daily_post_count - LAG(dpc.daily_post_count, 1, 0) OVER (
        PARTITION BY dpc.user_id
        ORDER BY dpc.post_date
    ) AS daily_change
FROM daily_post_cumulative dpc
INNER JOIN Users u ON dpc.user_id = u.user_id
ORDER BY u.username, dpc.post_date;


-- ============================================================================
-- 3. FIND MOST ACTIVE USERS WITH RANK/DENSE_RANK
-- ============================================================================
-- Ranks users by various activity metrics

CREATE OR REPLACE VIEW user_activity_ranking AS
SELECT
    user_id,
    username,
    total_posts,
    -- RANK: handles ties by skipping numbers
    RANK() OVER (
        ORDER BY total_posts DESC
    ) AS post_rank,
    -- DENSE_RANK: handles ties without skipping numbers
    DENSE_RANK() OVER (
        ORDER BY total_posts DESC
    ) AS post_dense_rank,
    -- Percentage rank
    PERCENT_RANK() OVER (
        ORDER BY total_posts DESC
    ) AS post_percentile,
    -- Cumulative distribution
    CUME_DIST() OVER (
        ORDER BY total_posts DESC
    ) AS cumulative_distribution,
    -- NTILE: divide into quartiles
    NTILE(4) OVER (
        ORDER BY total_posts DESC
    ) AS activity_quartile
FROM (
    SELECT
        u.user_id,
        u.username,
        COUNT(p.post_id) AS total_posts
    FROM Users u
    LEFT JOIN Posts p ON u.user_id = p.user_id AND p.deleted_at IS NULL
    GROUP BY u.user_id, u.username
) user_activity;

-- Query to display ranked users with activity levels
SELECT
    post_rank,
    post_dense_rank,
    username,
    total_posts,
    ROUND(post_percentile * 100, 2) AS percentile_score,
    CASE 
        WHEN activity_quartile = 1 THEN 'Top 25% (Most Active)'
        WHEN activity_quartile = 2 THEN 'Second Quartile'
        WHEN activity_quartile = 3 THEN 'Third Quartile'
        ELSE 'Bottom 25% (Least Active)'
    END AS activity_level
FROM user_activity_ranking
ORDER BY post_rank;

-- Find top 10 most active users with their ranking details
SELECT
    post_rank,
    username,
    total_posts,
    ROUND(post_percentile * 100, 2) AS percentile,
    ROUND(cumulative_distribution * 100, 2) AS cumulative_percentage
FROM user_activity_ranking
WHERE post_rank <= 10
ORDER BY post_rank;


-- ============================================================================
-- 4. COMPARE POSTS USING LAG/LEAD FUNCTIONS
-- ============================================================================
-- Compare current post with previous/next posts in the user's timeline

CREATE OR REPLACE VIEW post_comparison_analysis AS
SELECT
    user_id,
    post_id,
    content,
    created_at,
    -- Previous post information
    LAG(post_id, 1) OVER (
        PARTITION BY user_id
        ORDER BY created_at
    ) AS previous_post_id,
    LAG(created_at, 1) OVER (
        PARTITION BY user_id
        ORDER BY created_at
    ) AS previous_post_time,
    -- Next post information
    LEAD(post_id, 1) OVER (
        PARTITION BY user_id
        ORDER BY created_at
    ) AS next_post_id,
    LEAD(created_at, 1) OVER (
        PARTITION BY user_id
        ORDER BY created_at
    ) AS next_post_time,
    -- Time differences
    EXTRACT(HOUR FROM created_at - LAG(created_at, 1) OVER (
        PARTITION BY user_id
        ORDER BY created_at
    )) AS hours_since_previous,
    EXTRACT(HOUR FROM LEAD(created_at, 1) OVER (
        PARTITION BY user_id
        ORDER BY created_at
    ) - created_at) AS hours_until_next,
    -- Access posts from further back/ahead
    LAG(post_id, 2) OVER (
        PARTITION BY user_id
        ORDER BY created_at
    ) AS post_2_back,
    LEAD(post_id, 2) OVER (
        PARTITION BY user_id
        ORDER BY created_at
    ) AS post_2_ahead
FROM Posts
WHERE deleted_at IS NULL;

-- Query to display post timeline comparisons
SELECT
    u.username,
    pca.post_id,
    pca.content,
    pca.created_at,
    pca.previous_post_id,
    pca.hours_since_previous,
    pca.next_post_id,
    pca.hours_until_next,
    CASE
        WHEN pca.hours_since_previous IS NULL THEN 'First post'
        WHEN pca.hours_since_previous < 1 THEN 'Posted within the hour'
        WHEN pca.hours_since_previous < 24 THEN 'Posted within a day'
        ELSE 'Significant gap since last post'
    END AS posting_pattern
FROM post_comparison_analysis pca
INNER JOIN Users u ON pca.user_id = u.user_id
ORDER BY u.username, pca.created_at;


-- ============================================================================
-- ADVANCED ANALYTICS: POSTING CONSISTENCY ANALYSIS
-- ============================================================================
-- Combines multiple window functions for comprehensive posting behavior

CREATE OR REPLACE VIEW posting_consistency_metrics AS
SELECT
    user_id,
    username,
    post_count,
    -- Average hours between posts
    ROUND(
        EXTRACT(EPOCH FROM (last_post - first_post)) / 3600 / 
        NULLIF(post_count - 1, 0),
        2
    ) AS avg_hours_between_posts,
    -- Consistency: standard deviation of time gaps
    ROUND(
        STDDEV(hours_gap)::NUMERIC,
        2
    ) AS posting_consistency_score,
    -- Posting frequency per day
    ROUND(
        post_count::NUMERIC / NULLIF(
            EXTRACT(DAY FROM (last_post - first_post)) + 1,
            0
        ),
        2
    ) AS posts_per_day,
    -- Rank by consistency (lower stddev = more consistent)
    RANK() OVER (
        ORDER BY STDDEV(hours_gap) ASC NULLS LAST
    ) AS consistency_rank
FROM (
    SELECT
        u.user_id,
        u.username,
        COUNT(p.post_id) AS post_count,
        MIN(p.created_at) AS first_post,
        MAX(p.created_at) AS last_post,
        EXTRACT(HOUR FROM p.created_at - 
            LAG(p.created_at) OVER (
                PARTITION BY u.user_id
                ORDER BY p.created_at
            )
        ) AS hours_gap
    FROM Users u
    LEFT JOIN Posts p ON u.user_id = p.user_id AND p.deleted_at IS NULL
    GROUP BY u.user_id, u.username, hours_gap
) consistency_data
WHERE post_count > 1
GROUP BY user_id, username, post_count, first_post, last_post;

-- Query to display user posting consistency
SELECT
    consistency_rank,
    username,
    post_count,
    avg_hours_between_posts,
    posting_consistency_score,
    posts_per_day,
    CASE
        WHEN posting_consistency_score < 5 THEN 'Very Consistent'
        WHEN posting_consistency_score < 15 THEN 'Consistent'
        WHEN posting_consistency_score < 30 THEN 'Moderate'
        ELSE 'Irregular'
    END AS consistency_level
FROM posting_consistency_metrics
WHERE post_count > 5
ORDER BY consistency_rank;


-- ============================================================================
-- ADDITIONAL ANALYTICS: POST ENGAGEMENT TRENDS
-- ============================================================================
-- Track likes trend using window functions

CREATE OR REPLACE VIEW post_engagement_trends AS
SELECT
    user_id,
    post_id,
    created_at,
    like_count,
    -- Previous post likes
    LAG(like_count, 1, 0) OVER (
        PARTITION BY user_id
        ORDER BY created_at
    ) AS previous_like_count,
    -- Engagement trend
    like_count - LAG(like_count, 1, 0) OVER (
        PARTITION BY user_id
        ORDER BY created_at
    ) AS engagement_change,
    -- 3-post moving average of likes
    ROUND(
        AVG(like_count) OVER (
            PARTITION BY user_id
            ORDER BY created_at
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ),
        2
    ) AS moving_avg_likes_3post,
    -- Percentile of this post's likes among user's posts
    ROUND(
        PERCENT_RANK() OVER (
            PARTITION BY user_id
            ORDER BY like_count
        ) * 100,
        2
    ) AS like_percentile_by_user
FROM (
    SELECT
        p.user_id,
        p.post_id,
        p.created_at,
        COUNT(pl.like_id) AS like_count
    FROM Posts p
    LEFT JOIN Post_Likes pl ON p.post_id = pl.post_id
    WHERE p.deleted_at IS NULL
    GROUP BY p.post_id, p.user_id, p.created_at
) post_engagement;

-- Query to display engagement trends
SELECT
    u.username,
    pet.post_id,
    pet.created_at,
    pet.like_count,
    pet.previous_like_count,
    pet.engagement_change,
    pet.moving_avg_likes_3post,
    pet.like_percentile_by_user,
    CASE
        WHEN pet.engagement_change > 0 THEN '↑ Gaining traction'
        WHEN pet.engagement_change < 0 THEN '↓ Losing traction'
        ELSE '→ Stable'
    END AS trend_indicator
FROM post_engagement_trends pet
INNER JOIN Users u ON pet.user_id = u.user_id
WHERE pet.previous_like_count IS NOT NULL
ORDER BY u.username, pet.created_at;
