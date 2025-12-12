-- Complete Triggers Setup Script
-- Run this script to set up all triggers for the Social Media Database

-- =====================================================
-- STEP 1: Add updated_at columns
-- =====================================================
\echo 'Step 1: Adding updated_at columns...'
\i 02_Migrations/01_add_updated_at_columns.sql

-- =====================================================
-- STEP 2: Create audit log table
-- =====================================================
\echo 'Step 2: Creating audit log table...'
\i 02_Migrations/02_create_audit_log_table.sql

-- =====================================================
-- STEP 3: Create updated_at triggers
-- =====================================================
\echo 'Step 3: Creating updated_at triggers...'
\i 03_Triggers/01_updated_at_triggers.sql

-- =====================================================
-- STEP 4: Create audit log triggers
-- =====================================================
\echo 'Step 4: Creating audit log triggers...'
\i 03_Triggers/02_audit_log_triggers.sql

-- =====================================================
-- STEP 5: Create cascade cleanup triggers
-- =====================================================
\echo 'Step 5: Creating cascade cleanup triggers...'
\i 03_Triggers/03_cascade_cleanup_triggers.sql

-- =====================================================
-- Verify triggers were created
-- =====================================================
\echo 'Verifying triggers...'
SELECT 
    trigger_name,
    event_object_table AS table_name,
    action_timing AS timing,
    event_manipulation AS event
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

\echo 'Triggers setup completed successfully!'
