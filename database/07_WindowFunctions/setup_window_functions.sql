-- ============================================================================
-- Window Functions Setup Script
-- ============================================================================
-- Execute this script to create all window function views and setup indexes
-- for optimal performance
--
-- Usage: psql -U username -d database_name -f setup_window_functions.sql
-- ============================================================================

\echo 'Installing Window Functions Module...'

-- ============================================================================
-- Step 1: Create Indexes for Performance
-- ============================================================================
\echo 'Step 1: Creating indexes for window function optimization...'

CREATE INDEX IF NOT EXISTS idx_posts_user_created ON Posts(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_posts_user_deleted_created ON Posts(user_id, deleted_at, created_at);
CREATE INDEX IF NOT EXISTS idx_post_likes_post_id ON Post_Likes(post_id);
CREATE INDEX IF NOT EXISTS idx_post_likes_user_id ON Post_Likes(user_id);
CREATE INDEX IF NOT EXISTS idx_users_id ON Users(user_id);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON Posts(created_at);

\echo 'Indexes created successfully'

-- ============================================================================
-- Step 2: Drop existing views if they exist (for clean installation)
-- ============================================================================
\echo 'Step 2: Preparing environment...'

DROP VIEW IF EXISTS post_engagement_trends CASCADE;
DROP VIEW IF EXISTS posting_consistency_metrics CASCADE;
DROP VIEW IF EXISTS post_comparison_analysis CASCADE;
DROP VIEW IF EXISTS user_activity_ranking CASCADE;
DROP VIEW IF EXISTS daily_post_cumulative CASCADE;
DROP VIEW IF EXISTS user_post_sequence CASCADE;

\echo 'Environment prepared'

-- ============================================================================
-- Step 3: Create Window Function Views
-- ============================================================================
\echo 'Step 3: Creating window function views...'

-- View 1: User Post Sequence (ROW_NUMBER)
CREATE OR REPLACE VIEW user_post_sequence AS
SELECT
    user_id,
    post_id,
    content,
    created_at,
    ROW_NUMBER() OVER (
        PARTITION BY user_id 
        ORDER BY created_at ASC
    ) AS post_sequence_number,
    ROW_NUMBER() OVER (
        PARTITION BY user_id 
        ORDER BY created_at DESC
    ) AS post_reverse_sequence
FROM Posts
WHERE deleted_at IS NULL;

\echo '  ✓ Created user_post_sequence view'

-- View 2: Daily Post Cumulative (SUM with window frame)
CREATE OR REPLACE VIEW daily_post_cumulative AS
SELECT
    user_id,
    DATE(created_at) AS post_date,
    COUNT(*) OVER (
        PARTITION BY user_id
    ) AS total_posts_by_user,
    COUNT(*) AS daily_post_count,
    SUM(COUNT(*)) OVER (
        PARTITION BY user_id
        ORDER BY DATE(created_at)
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_posts,
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

\echo '  ✓ Created daily_post_cumulative view'

-- View 3: User Activity Ranking (RANK/DENSE_RANK)
CREATE OR REPLACE VIEW user_activity_ranking AS
SELECT
    user_id,
    username,
    total_posts,
    RANK() OVER (
        ORDER BY total_posts DESC
    ) AS post_rank,
    DENSE_RANK() OVER (
        ORDER BY total_posts DESC
    ) AS post_dense_rank,
    PERCENT_RANK() OVER (
        ORDER BY total_posts DESC
    ) AS post_percentile,
    CUME_DIST() OVER (
        ORDER BY total_posts DESC
    ) AS cumulative_distribution,
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

\echo '  ✓ Created user_activity_ranking view'

-- View 4: Post Comparison Analysis (LAG/LEAD)
CREATE OR REPLACE VIEW post_comparison_analysis AS
SELECT
    user_id,
    post_id,
    content,
    created_at,
    LAG(post_id, 1) OVER (
        PARTITION BY user_id
        ORDER BY created_at
    ) AS previous_post_id,
    LAG(created_at, 1) OVER (
        PARTITION BY user_id
        ORDER BY created_at
    ) AS previous_post_time,
    LEAD(post_id, 1) OVER (
        PARTITION BY user_id
        ORDER BY created_at
    ) AS next_post_id,
    LEAD(created_at, 1) OVER (
        PARTITION BY user_id
        ORDER BY created_at
    ) AS next_post_time,
    EXTRACT(HOUR FROM created_at - LAG(created_at, 1) OVER (
        PARTITION BY user_id
        ORDER BY created_at
    )) AS hours_since_previous,
    EXTRACT(HOUR FROM LEAD(created_at, 1) OVER (
        PARTITION BY user_id
        ORDER BY created_at
    ) - created_at) AS hours_until_next,
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

\echo '  ✓ Created post_comparison_analysis view'

-- View 5: Posting Consistency Metrics
CREATE OR REPLACE VIEW posting_consistency_metrics AS
SELECT
    user_id,
    username,
    post_count,
    ROUND(
        EXTRACT(EPOCH FROM (last_post - first_post)) / 3600 / 
        NULLIF(post_count - 1, 0),
        2
    ) AS avg_hours_between_posts,
    ROUND(
        STDDEV(hours_gap)::NUMERIC,
        2
    ) AS posting_consistency_score,
    ROUND(
        post_count::NUMERIC / NULLIF(
            EXTRACT(DAY FROM (last_post - first_post)) + 1,
            0
        ),
        2
    ) AS posts_per_day,
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

\echo '  ✓ Created posting_consistency_metrics view'

-- View 6: Post Engagement Trends
CREATE OR REPLACE VIEW post_engagement_trends AS
SELECT
    user_id,
    post_id,
    created_at,
    like_count,
    LAG(like_count, 1, 0) OVER (
        PARTITION BY user_id
        ORDER BY created_at
    ) AS previous_like_count,
    like_count - LAG(like_count, 1, 0) OVER (
        PARTITION BY user_id
        ORDER BY created_at
    ) AS engagement_change,
    ROUND(
        AVG(like_count) OVER (
            PARTITION BY user_id
            ORDER BY created_at
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ),
        2
    ) AS moving_avg_likes_3post,
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

\echo '  ✓ Created post_engagement_trends view'

-- ============================================================================
-- Step 4: Grant Permissions
-- ============================================================================
\echo 'Step 4: Granting permissions...'

-- Grant read permissions on views to public role
GRANT SELECT ON user_post_sequence TO public;
GRANT SELECT ON daily_post_cumulative TO public;
GRANT SELECT ON user_activity_ranking TO public;
GRANT SELECT ON post_comparison_analysis TO public;
GRANT SELECT ON posting_consistency_metrics TO public;
GRANT SELECT ON post_engagement_trends TO public;

\echo 'Permissions granted'

-- ============================================================================
-- Step 5: Verification
-- ============================================================================
\echo 'Step 5: Verifying installation...'

-- Count records in each view
\echo ''
\echo '--- View Row Counts ---'
SELECT 'user_post_sequence' as view_name, COUNT(*) as row_count FROM user_post_sequence
UNION ALL
SELECT 'daily_post_cumulative', COUNT(*) FROM daily_post_cumulative
UNION ALL
SELECT 'user_activity_ranking', COUNT(*) FROM user_activity_ranking
UNION ALL
SELECT 'post_comparison_analysis', COUNT(*) FROM post_comparison_analysis
UNION ALL
SELECT 'posting_consistency_metrics', COUNT(*) FROM posting_consistency_metrics
UNION ALL
SELECT 'post_engagement_trends', COUNT(*) FROM post_engagement_trends;

\echo ''
\echo '--- Created Indexes ---'
SELECT
    schemaname,
    tablename,
    indexname
FROM pg_indexes
WHERE tablename IN ('posts', 'post_likes', 'users')
  AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;

-- ============================================================================
-- Summary
-- ============================================================================
\echo ''
\echo '============================================================================'
\echo 'Window Functions Installation Complete!'
\echo '============================================================================'
\echo ''
\echo 'Created Views:'
\echo '  ✓ user_post_sequence - ROW_NUMBER post chronological numbering'
\echo '  ✓ daily_post_cumulative - Running totals of daily posts'
\echo '  ✓ user_activity_ranking - RANK/DENSE_RANK user rankings'
\echo '  ✓ post_comparison_analysis - LAG/LEAD post comparison'
\echo '  ✓ posting_consistency_metrics - Posting pattern analysis'
\echo '  ✓ post_engagement_trends - Engagement trend tracking'
\echo ''
\echo 'Created Indexes:'
\echo '  ✓ idx_posts_user_created'
\echo '  ✓ idx_posts_user_deleted_created'
\echo '  ✓ idx_post_likes_post_id'
\echo '  ✓ idx_post_likes_user_id'
\echo '  ✓ idx_users_id'
\echo '  ✓ idx_posts_created_at'
\echo ''
\echo 'Usage:'
\echo '  SELECT * FROM user_post_sequence;'
\echo '  SELECT * FROM daily_post_cumulative;'
\echo '  SELECT * FROM user_activity_ranking;'
\echo '  SELECT * FROM post_comparison_analysis;'
\echo '  SELECT * FROM posting_consistency_metrics;'
\echo '  SELECT * FROM post_engagement_trends;'
\echo ''
\echo 'Documentation:'
\echo '  See WINDOW_FUNCTIONS_README.md for detailed explanations'
\echo '  See 02_practical_examples.sql for runnable examples'
\echo '============================================================================'
\echo ''
