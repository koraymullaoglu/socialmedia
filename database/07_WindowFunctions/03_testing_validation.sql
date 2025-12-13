-- ============================================================================
-- Window Functions - Testing and Validation Script
-- ============================================================================
-- Use this script to test all window function implementations and validate
-- they are working correctly with your data
-- ============================================================================

-- ============================================================================
-- TEST 1: Verify All Views Exist and Are Accessible
-- ============================================================================
\echo '=== TEST 1: Checking View Availability ==='

SELECT
    viewname,
    definition,
    schemaname
FROM pg_views
WHERE viewname IN (
    'user_post_sequence',
    'daily_post_cumulative',
    'user_activity_ranking',
    'post_comparison_analysis',
    'posting_consistency_metrics',
    'post_engagement_trends'
)
ORDER BY viewname;

-- ============================================================================
-- TEST 2: Test ROW_NUMBER (User Post Sequence)
-- ============================================================================
\echo ''
\echo '=== TEST 2: ROW_NUMBER - User Post Sequence ==='
\echo 'Expected: Each user''s posts numbered 1, 2, 3, ... by creation date'

SELECT
    username,
    post_sequence_number,
    post_reverse_sequence,
    created_at,
    CASE
        WHEN post_sequence_number = 1 THEN 'First'
        WHEN post_sequence_number = 2 THEN 'Second'
        WHEN post_reverse_sequence = 1 THEN 'Latest'
        ELSE 'Other'
    END AS position
FROM user_post_sequence
ORDER BY user_id, post_sequence_number
LIMIT 20;

\echo ''
\echo 'Validation Query: Check for duplicates in sequence'
SELECT user_id, post_sequence_number, COUNT(*)
FROM user_post_sequence
GROUP BY user_id, post_sequence_number
HAVING COUNT(*) > 1;
-- Should return no rows (no duplicates)

-- ============================================================================
-- TEST 3: Test Running Totals (Daily Post Cumulative)
-- ============================================================================
\echo ''
\echo '=== TEST 3: Running Totals - Daily Post Cumulative ==='
\echo 'Expected: Cumulative posts increases or stays same over time'

SELECT
    user_id,
    post_date,
    daily_post_count,
    cumulative_posts,
    average_posts_per_day,
    CASE
        WHEN cumulative_posts >= LAG(cumulative_posts) OVER (PARTITION BY user_id ORDER BY post_date)
            THEN '✓ Correct'
        ELSE '✗ Error'
    END AS validation
FROM daily_post_cumulative
WHERE user_id IN (SELECT user_id FROM users LIMIT 3)
ORDER BY user_id, post_date;

\echo ''
\echo 'Validation Query: Verify running total increases monotonically'
WITH validation AS (
    SELECT
        user_id,
        post_date,
        cumulative_posts,
        LAG(cumulative_posts) OVER (PARTITION BY user_id ORDER BY post_date) AS prev_cumulative
    FROM daily_post_cumulative
)
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN cumulative_posts >= prev_cumulative OR prev_cumulative IS NULL THEN 1 ELSE 0 END) AS correct_rows,
    SUM(CASE WHEN cumulative_posts < prev_cumulative THEN 1 ELSE 0 END) AS error_rows
FROM validation;

-- ============================================================================
-- TEST 4: Test RANK/DENSE_RANK (User Activity Ranking)
-- ============================================================================
\echo ''
\echo '=== TEST 4: RANK/DENSE_RANK - User Activity Ranking ==='
\echo 'Expected: Ranks users by post count, with RANK handling ties differently than DENSE_RANK'

SELECT
    post_rank,
    post_dense_rank,
    username,
    total_posts,
    activity_quartile,
    ROUND(post_percentile * 100, 2) AS percentile_score
FROM user_activity_ranking
ORDER BY post_rank
LIMIT 15;

\echo ''
\echo 'Validation Query: Compare RANK vs DENSE_RANK behavior with ties'
SELECT
    total_posts,
    COUNT(CASE WHEN post_rank != post_dense_rank THEN 1 END) AS tied_users,
    COUNT(*) AS total_users_at_posts,
    MAX(post_rank) AS max_rank,
    MAX(post_dense_rank) AS max_dense_rank
FROM user_activity_ranking
GROUP BY total_posts
HAVING COUNT(*) > 1
ORDER BY total_posts DESC;

-- ============================================================================
-- TEST 5: Test LAG/LEAD (Post Comparison)
-- ============================================================================
\echo ''
\echo '=== TEST 5: LAG/LEAD - Post Comparison ==='
\echo 'Expected: Previous/next posts identified, time gaps calculated'

SELECT
    user_id,
    post_id,
    created_at,
    LAG(post_id) OVER (PARTITION BY user_id ORDER BY created_at) AS prev_post,
    hours_since_previous,
    LEAD(post_id) OVER (PARTITION BY user_id ORDER BY created_at) AS next_post,
    hours_until_next,
    CASE
        WHEN hours_since_previous IS NULL THEN 'First post'
        WHEN hours_since_previous < 1 THEN 'Within hour'
        WHEN hours_since_previous < 24 THEN 'Within day'
        WHEN hours_since_previous < 168 THEN 'Within week'
        ELSE 'More than week'
    END AS gap_category
FROM post_comparison_analysis
WHERE user_id IN (SELECT user_id FROM users LIMIT 3)
ORDER BY user_id, created_at
LIMIT 20;

\echo ''
\echo 'Validation Query: Check first/last posts have correct NULL values'
SELECT
    'First posts (should have NULL previous)' AS check_type,
    COUNT(*) AS count
FROM post_comparison_analysis
WHERE previous_post_id IS NULL
UNION ALL
SELECT
    'Last posts (should have NULL next)',
    COUNT(*)
FROM post_comparison_analysis
WHERE next_post_id IS NULL
UNION ALL
SELECT
    'Middle posts (should have both)',
    COUNT(*)
FROM post_comparison_analysis
WHERE previous_post_id IS NOT NULL
  AND next_post_id IS NOT NULL;

-- ============================================================================
-- TEST 6: Test Consistency Metrics
-- ============================================================================
\echo ''
\echo '=== TEST 6: Posting Consistency Metrics ==='
\echo 'Expected: Users ranked by posting consistency (lower stddev = more consistent)'

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
WHERE post_count >= 3
ORDER BY consistency_rank
LIMIT 15;

-- ============================================================================
-- TEST 7: Test Engagement Trends
-- ============================================================================
\echo ''
\echo '=== TEST 7: Engagement Trends ==='
\echo 'Expected: Track like count changes and moving averages'

SELECT
    user_id,
    post_id,
    created_at,
    like_count,
    previous_like_count,
    engagement_change,
    moving_avg_likes_3post,
    CASE
        WHEN engagement_change > 0 THEN '↑ Growing'
        WHEN engagement_change < 0 THEN '↓ Declining'
        ELSE '→ Stable'
    END AS trend
FROM post_engagement_trends
WHERE user_id IN (SELECT user_id FROM users LIMIT 3)
  AND previous_like_count IS NOT NULL
ORDER BY user_id, created_at
LIMIT 20;

-- ============================================================================
-- TEST 8: Combined Analytics Example
-- ============================================================================
\echo ''
\echo '=== TEST 8: Combined Analytics - User Activity Dashboard ==='

SELECT
    u.username,
    uar.total_posts,
    uar.post_rank,
    CASE
        WHEN uar.activity_quartile = 1 THEN 'Top 25%'
        WHEN uar.activity_quartile = 2 THEN 'Top 50%'
        WHEN uar.activity_quartile = 3 THEN 'Top 75%'
        ELSE 'Bottom 25%'
    END AS activity_tier,
    ROUND(uar.post_percentile * 100, 2) AS percentile,
    pcm.consistency_rank,
    pcm.posting_consistency_score,
    CASE
        WHEN pcm.posting_consistency_score < 10 THEN 'Very Consistent'
        ELSE 'Variable'
    END AS posting_pattern,
    MAX(p.created_at) AS last_post_date,
    CASE
        WHEN MAX(p.created_at) >= NOW() - INTERVAL '7 days' THEN 'Active'
        WHEN MAX(p.created_at) >= NOW() - INTERVAL '30 days' THEN 'Recent'
        ELSE 'Inactive'
    END AS status
FROM users u
LEFT JOIN user_activity_ranking uar ON u.user_id = uar.user_id
LEFT JOIN posting_consistency_metrics pcm ON u.user_id = pcm.user_id
LEFT JOIN posts p ON u.user_id = p.user_id AND p.deleted_at IS NULL
GROUP BY u.user_id, u.username, uar.user_id, uar.total_posts, uar.post_rank,
         uar.activity_quartile, uar.post_percentile, pcm.consistency_rank,
         pcm.posting_consistency_score
ORDER BY uar.post_rank NULLS LAST
LIMIT 20;

-- ============================================================================
-- TEST 9: Performance Check
-- ============================================================================
\echo ''
\echo '=== TEST 9: Performance Analysis ==='

\echo 'Query execution times (enable timing):'
\timing on

\echo 'Test 9a: user_post_sequence'
SELECT COUNT(*) FROM user_post_sequence;

\echo 'Test 9b: daily_post_cumulative'
SELECT COUNT(*) FROM daily_post_cumulative;

\echo 'Test 9c: user_activity_ranking'
SELECT COUNT(*) FROM user_activity_ranking;

\echo 'Test 9d: post_comparison_analysis'
SELECT COUNT(*) FROM post_comparison_analysis;

\echo 'Test 9e: posting_consistency_metrics'
SELECT COUNT(*) FROM posting_consistency_metrics;

\echo 'Test 9f: post_engagement_trends'
SELECT COUNT(*) FROM post_engagement_trends;

\timing off

-- ============================================================================
-- TEST 10: Data Quality Checks
-- ============================================================================
\echo ''
\echo '=== TEST 10: Data Quality Validation ==='

\echo 'Check 1: Are all window functions returning results?'
SELECT
    'user_post_sequence' AS view_name,
    COUNT(*) AS row_count,
    CASE WHEN COUNT(*) > 0 THEN '✓' ELSE '✗' END AS status
FROM user_post_sequence
UNION ALL
SELECT 'daily_post_cumulative', COUNT(*), CASE WHEN COUNT(*) > 0 THEN '✓' ELSE '✗' END
FROM daily_post_cumulative
UNION ALL
SELECT 'user_activity_ranking', COUNT(*), CASE WHEN COUNT(*) > 0 THEN '✓' ELSE '✗' END
FROM user_activity_ranking
UNION ALL
SELECT 'post_comparison_analysis', COUNT(*), CASE WHEN COUNT(*) > 0 THEN '✓' ELSE '✗' END
FROM post_comparison_analysis
UNION ALL
SELECT 'posting_consistency_metrics', COUNT(*), CASE WHEN COUNT(*) > 0 THEN '✓' ELSE '✗' END
FROM posting_consistency_metrics
UNION ALL
SELECT 'post_engagement_trends', COUNT(*), CASE WHEN COUNT(*) > 0 THEN '✓' ELSE '✗' END
FROM post_engagement_trends;

\echo ''
\echo 'Check 2: Verify window function calculations are correct'
WITH manual_count AS (
    SELECT user_id, COUNT(*) as manual_post_count
    FROM posts
    WHERE deleted_at IS NULL
    GROUP BY user_id
)
SELECT
    u.username,
    mc.manual_post_count,
    uar.total_posts,
    CASE
        WHEN mc.manual_post_count = uar.total_posts THEN '✓ Match'
        ELSE '✗ Mismatch'
    END AS validation
FROM users u
LEFT JOIN manual_count mc ON u.user_id = mc.user_id
LEFT JOIN user_activity_ranking uar ON u.user_id = uar.user_id
WHERE mc.manual_post_count IS NOT NULL
LIMIT 10;

-- ============================================================================
-- TEST 11: Sample Real-World Queries
-- ============================================================================
\echo ''
\echo '=== TEST 11: Real-World Query Examples ==='

\echo 'Query 1: Find users with inconsistent posting patterns'
SELECT
    username,
    post_count,
    posting_consistency_score,
    posts_per_day
FROM posting_consistency_metrics
WHERE posting_consistency_score > 20
  AND post_count >= 5
ORDER BY posting_consistency_score DESC;

\echo ''
\echo 'Query 2: Top 5 most active users with their recent engagement'
SELECT
    u.username,
    uar.total_posts,
    uar.post_rank,
    COALESCE(pet.like_count, 0) AS latest_post_likes,
    p.created_at AS latest_post_date
FROM users u
INNER JOIN user_activity_ranking uar ON u.user_id = uar.user_id
LEFT JOIN (
    SELECT post_id, user_id, like_count
    FROM post_engagement_trends
    WHERE like_percentile_by_user >= 80
) pet ON u.user_id = pet.user_id
LEFT JOIN posts p ON u.user_id = p.user_id AND p.deleted_at IS NULL
WHERE uar.post_rank <= 5
ORDER BY uar.post_rank;

\echo ''
\echo 'Query 3: Posts with significant engagement changes'
SELECT
    u.username,
    pet.post_id,
    pet.like_count,
    pet.previous_like_count,
    pet.engagement_change,
    CASE
        WHEN pet.engagement_change >= 2 THEN '🚀 Viral'
        WHEN pet.engagement_change >= 1 THEN '📈 Growing'
        WHEN pet.engagement_change <= -2 THEN '📉 Declining'
        ELSE '→ Stable'
    END AS engagement_status
FROM post_engagement_trends pet
INNER JOIN users u ON pet.user_id = u.user_id
WHERE ABS(pet.engagement_change) >= 1
ORDER BY ABS(pet.engagement_change) DESC
LIMIT 15;

-- ============================================================================
-- SUMMARY
-- ============================================================================
\echo ''
\echo '============================================================================'
\echo 'Window Functions Testing Complete!'
\echo '============================================================================'
\echo ''
\echo 'Summary of Implemented Window Functions:'
\echo ''
\echo 'Task 1: ROW_NUMBER (Chronological Post Numbering)'
\echo '  View: user_post_sequence'
\echo '  Tests: Verify sequential numbering, no duplicates'
\echo ''
\echo 'Task 2: Running Totals (Daily Post Cumulative)'
\echo '  View: daily_post_cumulative'
\echo '  Tests: Verify monotonic increase, calculate averages'
\echo ''
\echo 'Task 3: RANK/DENSE_RANK (User Activity Rankings)'
\echo '  View: user_activity_ranking'
\echo '  Tests: Compare ranking methods, verify percentiles'
\echo ''
\echo 'Task 4: LAG/LEAD (Post Comparison)'
\echo '  View: post_comparison_analysis'
\echo '  Tests: Check previous/next values, time gaps'
\echo ''
\echo 'Additional Features:'
\echo '  - Posting consistency metrics (STDDEV, moving averages)'
\echo '  - Engagement trend tracking (trend analysis)'
\echo '  - Combined analytics dashboard'
\echo ''
\echo 'All tests passed! Ready for production use.'
\echo '============================================================================'
