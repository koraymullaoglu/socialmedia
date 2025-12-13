-- ============================================================================
-- Migration: Add CHECK Constraints for Data Integrity
-- ============================================================================
-- Purpose: Add database-level validation to ensure data quality
-- Created: 2024
-- ============================================================================

\echo '===================================================================='
\echo 'Migration: Adding CHECK Constraints'
\echo '===================================================================='
\echo ''

-- ============================================================================
-- 1. POSTS TABLE: Either content OR media_url must be present
-- ============================================================================

\echo 'Adding CHECK constraint to Posts table...'

-- Add constraint: At least one of content or media_url must be present
ALTER TABLE Posts
ADD CONSTRAINT chk_posts_content_or_media
CHECK (
    (content IS NOT NULL AND content != '') 
    OR 
    (media_url IS NOT NULL AND media_url != '')
);

\echo '✓ Posts: content OR media_url constraint added'
\echo ''

-- ============================================================================
-- 2. USERS TABLE: Email format validation
-- ============================================================================

\echo 'Adding CHECK constraint to Users table...'

-- Add constraint: Email must match valid email format
-- Pattern: local-part@domain.tld
-- Allows: letters, numbers, dots, hyphens, underscores before @
-- Requires: @ symbol, domain name, dot, and TLD (2+ chars)
ALTER TABLE Users
ADD CONSTRAINT chk_users_email_format
CHECK (
    email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
);

\echo '✓ Users: email format validation constraint added'
\echo ''

-- ============================================================================
-- 3. COMMENTS TABLE: Minimum 1 character content
-- ============================================================================

\echo 'Adding CHECK constraint to Comments table...'

-- Add constraint: Content must have at least 1 non-whitespace character
ALTER TABLE Comments
ADD CONSTRAINT chk_comments_min_length
CHECK (
    LENGTH(TRIM(content)) >= 1
);

\echo '✓ Comments: minimum length constraint added'
\echo ''

-- ============================================================================
-- 4. MESSAGES TABLE: Sender and receiver cannot be the same
-- ============================================================================

\echo 'Adding CHECK constraint to Messages table...'

-- Add constraint: Sender cannot send message to themselves
ALTER TABLE Messages
ADD CONSTRAINT chk_messages_different_users
CHECK (
    sender_id != receiver_id
);

\echo '✓ Messages: different users constraint added'
\echo ''

-- ============================================================================
-- VERIFICATION: List all CHECK constraints
-- ============================================================================

\echo '===================================================================='
\echo 'Verification: Checking all constraints'
\echo '===================================================================='
\echo ''

-- Query to display all CHECK constraints
SELECT 
    tc.table_name,
    tc.constraint_name,
    cc.check_clause
FROM information_schema.table_constraints tc
JOIN information_schema.check_constraints cc 
    ON tc.constraint_name = cc.constraint_name
WHERE tc.table_schema = 'public'
  AND tc.constraint_type = 'CHECK'
  AND tc.table_name IN ('posts', 'users', 'comments', 'messages')
ORDER BY tc.table_name, tc.constraint_name;

\echo ''
\echo '===================================================================='
\echo 'Migration Complete!'
\echo '===================================================================='
\echo ''
\echo 'Summary of added constraints:'
\echo '  1. Posts: content OR media_url must be present'
\echo '  2. Users: email format validation (regex)'
\echo '  3. Comments: minimum 1 character content'
\echo '  4. Messages: sender != receiver'
\echo ''
\echo 'Next steps:'
\echo '  1. Test constraints with invalid data'
\echo '  2. Update application code to handle constraint violations'
\echo '  3. Document constraint rules in API documentation'
\echo '===================================================================='
