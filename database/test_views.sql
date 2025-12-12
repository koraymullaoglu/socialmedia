-- Test Script for Database Views
-- This script tests all the views we've created

\echo '========================================='
\echo 'TESTING DATABASE VIEWS'
\echo '========================================='

-- =====================================================
-- TEST 1: Test user_feed_view
-- =====================================================
\echo ''
\echo 'TEST 1: Testing user_feed_view...'
\echo '---------------------------------------'

-- Count total rows in view
SELECT COUNT(*) AS total_feed_items FROM user_feed_view;

-- Show sample data (limit to 5 rows)
\echo ''
\echo 'Sample feed items:'
SELECT 
    post_id,
    username,
    content,
    like_count,
    comment_count,
    viewing_user_id,
    created_at
FROM user_feed_view
LIMIT 5;

-- Test filtering by specific user
\echo ''
\echo 'Feed for user_id = 1:'
SELECT COUNT(*) AS feed_count_for_user_1 
FROM user_feed_view 
WHERE viewing_user_id = 1;

-- =====================================================
-- TEST 2: Test popular_posts_view
-- =====================================================
\echo ''
\echo 'TEST 2: Testing popular_posts_view...'
\echo '---------------------------------------'

-- Count total posts
SELECT COUNT(*) AS total_posts FROM popular_posts_view;

-- Show top 5 most popular posts
\echo ''
\echo 'Top 5 popular posts:'
SELECT 
    post_id,
    username,
    LEFT(content, 50) AS content_preview,
    like_count,
    comment_count,
    engagement_score,
    is_recent
FROM popular_posts_view
ORDER BY engagement_score DESC
LIMIT 5;

-- Count recent popular posts
\echo ''
\echo 'Recent popular posts (last 7 days):'
SELECT COUNT(*) AS recent_popular_posts 
FROM popular_posts_view 
WHERE is_recent = true;

-- =====================================================
-- TEST 3: Test active_users_view
-- =====================================================
\echo ''
\echo 'TEST 3: Testing active_users_view...'
\echo '---------------------------------------'

-- Count active users
SELECT COUNT(*) AS total_active_users FROM active_users_view;

-- Show top 5 most active users
\echo ''
\echo 'Top 5 most active users:'
SELECT 
    user_id,
    username,
    posts_last_7_days,
    likes_last_7_days,
    comments_last_7_days,
    total_activity,
    last_activity_at
FROM active_users_view
ORDER BY total_activity DESC
LIMIT 5;

-- Activity breakdown
\echo ''
\echo 'Activity breakdown:'
SELECT 
    SUM(posts_last_7_days) AS total_posts,
    SUM(likes_last_7_days) AS total_likes,
    SUM(comments_last_7_days) AS total_comments,
    SUM(total_activity) AS total_activity
FROM active_users_view;

-- =====================================================
-- TEST 4: Test community_statistics_view
-- =====================================================
\echo ''
\echo 'TEST 4: Testing community_statistics_view...'
\echo '---------------------------------------'

-- Count total communities
SELECT COUNT(*) AS total_communities FROM community_statistics_view;

-- Show community statistics
\echo ''
\echo 'Community statistics:'
SELECT 
    community_id,
    community_name,
    total_members,
    total_posts,
    posts_last_7_days,
    activity_level,
    avg_likes_per_post
FROM community_statistics_view
ORDER BY total_members DESC
LIMIT 5;

-- Activity level distribution
\echo ''
\echo 'Communities by activity level:'
SELECT 
    activity_level,
    COUNT(*) AS community_count
FROM community_statistics_view
GROUP BY activity_level
ORDER BY 
    CASE activity_level
        WHEN 'active' THEN 1
        WHEN 'moderate' THEN 2
        WHEN 'inactive' THEN 3
    END;

-- =====================================================
-- TEST 5: Performance check
-- =====================================================
\echo ''
\echo 'TEST 5: Performance check...'
\echo '---------------------------------------'

-- Check view query performance
\echo ''
\echo 'Checking query performance (EXPLAIN ANALYZE):'

\echo ''
\echo 'user_feed_view performance:'
EXPLAIN ANALYZE 
SELECT * FROM user_feed_view WHERE viewing_user_id = 1 LIMIT 10;

\echo ''
\echo 'popular_posts_view performance:'
EXPLAIN ANALYZE 
SELECT * FROM popular_posts_view LIMIT 10;

\echo ''
\echo 'active_users_view performance:'
EXPLAIN ANALYZE 
SELECT * FROM active_users_view LIMIT 10;

\echo ''
\echo 'community_statistics_view performance:'
EXPLAIN ANALYZE 
SELECT * FROM community_statistics_view LIMIT 10;

-- =====================================================
-- Verify all views exist
-- =====================================================
\echo ''
\echo 'Verifying all views exist...'
\echo '---------------------------------------'

SELECT 
    table_name AS view_name,
    CASE 
        WHEN table_name IS NOT NULL THEN '✓ Exists'
        ELSE '✗ Missing'
    END AS status
FROM information_schema.views
WHERE table_schema = 'public'
  AND table_name IN (
    'user_feed_view',
    'popular_posts_view',
    'active_users_view',
    'community_statistics_view'
  )
ORDER BY table_name;

\echo ''
\echo '========================================='
\echo 'ALL VIEW TESTS COMPLETED!'
\echo '========================================='
