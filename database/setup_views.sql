-- Complete Views Setup Script
-- Run this script to create all views for the Social Media Database

\echo '========================================='
\echo 'CREATING DATABASE VIEWS'
\echo '========================================='

-- =====================================================
-- VIEW 1: User Feed View
-- =====================================================
\echo ''
\echo 'Creating user_feed_view...'
\i 04_Views/01_user_feed_view.sql
\echo '✓ user_feed_view created'

-- =====================================================
-- VIEW 2: Popular Posts View
-- =====================================================
\echo ''
\echo 'Creating popular_posts_view...'
\i 04_Views/02_popular_posts_view.sql
\echo '✓ popular_posts_view created'

-- =====================================================
-- VIEW 3: Active Users View
-- =====================================================
\echo ''
\echo 'Creating active_users_view...'
\i 04_Views/03_active_users_view.sql
\echo '✓ active_users_view created'

-- =====================================================
-- VIEW 4: Community Statistics View
-- =====================================================
\echo ''
\echo 'Creating community_statistics_view...'
\i 04_Views/04_community_statistics_view.sql
\echo '✓ community_statistics_view created'

-- =====================================================
-- Verify views were created
-- =====================================================
\echo ''
\echo 'Verifying views...'
SELECT 
    table_name AS view_name,
    view_definition
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
\echo 'ALL VIEWS CREATED SUCCESSFULLY!'
\echo '========================================='
