# CTE Module Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying the CTE (Common Table Expressions) module to your PostgreSQL database.

---

## Prerequisites

- PostgreSQL 12.0 or higher (for MATERIALIZED/NOT MATERIALIZED hints)
- Existing database with Users, Posts, Comments, and Follows tables
- psql command-line tool or database management interface
- Sufficient privileges to create functions, views, and indexes

---

## Deployment Methods

### Method 1: Quick Installation (Recommended)

Run the setup script to install everything at once:

```bash
psql -U your_username -d your_database -f setup_ctes.sql
```

This will:
1. Create all CTE functions
2. Create analytical views
3. Add supporting indexes
4. Display installation progress

**Estimated time:** 1-2 minutes

---

### Method 2: Manual Installation

If you prefer step-by-step control:

#### Step 1: Deploy Functions

```bash
psql -U your_username -d your_database -f 01_cte_examples.sql
```

This creates:
- `get_comment_thread(post_id)` - Recursive comment tree traversal
- `get_comment_ancestors(comment_id)` - Walk up comment hierarchy
- `get_friend_of_friend_recommendations(user_id)` - Social graph 2-hop traversal
- `get_social_network_distance(from_user, to_user)` - Shortest path calculation
- `compare_query_performance()` - CTE vs Subquery benchmarking

#### Step 2: Verify Installation

```bash
psql -U your_username -d your_database -f 03_testing_validation.sql
```

This runs 21 comprehensive tests covering:
- Recursive CTE functionality
- Friend-of-friend algorithms
- Performance benchmarks
- Edge case handling
- Cycle detection

#### Step 3: Review Examples

```bash
psql -U your_username -d your_database -f 02_practical_examples.sql
```

15 practical examples demonstrating real-world usage patterns.

---

## Post-Deployment Validation

### Test 1: Verify Functions Exist

```sql
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_name IN (
    'get_comment_thread',
    'get_comment_ancestors',
    'get_friend_of_friend_recommendations',
    'get_social_network_distance',
    'compare_query_performance'
)
ORDER BY routine_name;
```

**Expected output:** 5 functions

### Test 2: Verify Views Exist

```sql
SELECT 
    table_name,
    table_type
FROM information_schema.tables
WHERE table_name IN (
    'comment_thread_with_metrics',
    'advanced_friend_recommendations'
)
ORDER BY table_name;
```

**Expected output:** 2 views

### Test 3: Verify Indexes

```sql
SELECT 
    indexname,
    tablename
FROM pg_indexes
WHERE indexname IN (
    'idx_comments_parent_post',
    'idx_follows_relationships',
    'idx_follows_status'
)
ORDER BY indexname;
```

**Expected output:** 3 indexes

### Test 4: Run Sample Query

```sql
-- Test comment thread retrieval
SELECT * FROM get_comment_thread(1) LIMIT 5;

-- Test friend recommendations
SELECT * FROM get_friend_of_friend_recommendations(1) LIMIT 5;
```

---

## Performance Tuning

### Index Optimization

The setup script creates three critical indexes:

```sql
-- For comment traversal
CREATE INDEX idx_comments_parent_post 
ON Comments(parent_comment_id, post_id);

-- For follow relationships
CREATE INDEX idx_follows_relationships 
ON Follows(follower_id, following_id, status_id);

-- For follow lookups
CREATE INDEX idx_follows_status 
ON Follows(status_id, following_id);
```

### Additional Indexes (Optional)

For high-traffic systems, consider:

```sql
-- For user lookups in comment threads
CREATE INDEX idx_comments_user_post 
ON Comments(user_id, post_id);

-- For bidirectional follow queries
CREATE INDEX idx_follows_reverse 
ON Follows(following_id, follower_id, status_id);

-- For post-based comment queries
CREATE INDEX idx_comments_post_created 
ON Comments(post_id, created_at);
```

### Query Tuning

Monitor slow queries:

```sql
-- Check execution plans
EXPLAIN ANALYZE SELECT * FROM get_comment_thread(1);
EXPLAIN ANALYZE SELECT * FROM get_friend_of_friend_recommendations(1);

-- Compare approaches
SELECT * FROM compare_query_performance();
```

---

## Configuration Options

### PostgreSQL Settings

For optimal recursive query performance:

```sql
-- Increase work memory for complex CTEs
SET work_mem = '256MB';

-- Adjust max recursion depth (default: unlimited)
-- Note: Application-level limits are enforced in functions
```

### Function Parameters

#### get_comment_thread()

```sql
-- Modify depth limit (default: 10 levels)
-- In 01_cte_examples.sql, line ~30:
WHERE ct.depth < 10  -- Change this value
```

#### get_social_network_distance()

```sql
-- Modify max distance (default: 6 degrees)
-- In 01_cte_examples.sql, line ~280:
WHERE sp.distance < 6  -- Change this value
```

---

## Rollback Procedure

To completely remove the CTE module:

```sql
-- Drop views
DROP VIEW IF EXISTS comment_thread_with_metrics CASCADE;
DROP VIEW IF EXISTS advanced_friend_recommendations CASCADE;

-- Drop functions
DROP FUNCTION IF EXISTS get_comment_thread(INTEGER) CASCADE;
DROP FUNCTION IF EXISTS get_comment_ancestors(INTEGER) CASCADE;
DROP FUNCTION IF EXISTS get_friend_of_friend_recommendations(INTEGER) CASCADE;
DROP FUNCTION IF EXISTS get_social_network_distance(INTEGER, INTEGER) CASCADE;
DROP FUNCTION IF EXISTS compare_query_performance() CASCADE;

-- Drop indexes (optional - may be used by other modules)
DROP INDEX IF EXISTS idx_comments_parent_post;
DROP INDEX IF EXISTS idx_follows_relationships;
DROP INDEX IF EXISTS idx_follows_status;
```

---

## Troubleshooting

### Issue: Function already exists

**Error:**
```
ERROR: function get_comment_thread(integer) already exists
```

**Solution:**
```sql
-- Drop existing function first
DROP FUNCTION IF EXISTS get_comment_thread(INTEGER);

-- Then re-run setup
\i setup_ctes.sql
```

### Issue: Slow recursive queries

**Symptoms:** Queries taking > 5 seconds

**Solutions:**

1. **Check indexes:**
   ```sql
   SELECT * FROM pg_stat_user_indexes 
   WHERE relname IN ('Comments', 'Follows');
   ```

2. **Reduce recursion depth:**
   ```sql
   -- In functions, lower the depth limit
   WHERE depth < 5  -- Instead of 10
   ```

3. **Add materialization hint (PostgreSQL 12+):**
   ```sql
   WITH expensive_calc AS MATERIALIZED (
       SELECT ...
   )
   ```

### Issue: Out of memory errors

**Error:**
```
ERROR: out of shared memory
```

**Solutions:**

1. **Increase work_mem:**
   ```sql
   SET work_mem = '512MB';
   ```

2. **Use temp tables instead:**
   ```sql
   CREATE TEMP TABLE comment_cache AS
   SELECT * FROM get_comment_thread(1);
   
   SELECT * FROM comment_cache WHERE depth < 3;
   ```

3. **Limit result sets:**
   ```sql
   SELECT * FROM get_comment_thread(1)
   WHERE depth < 5  -- Add depth filter
   LIMIT 100;  -- Add row limit
   ```

### Issue: Infinite recursion

**Error:**
```
ERROR: infinite recursion detected
```

**Solution:**
The functions include termination conditions. Verify data integrity:

```sql
-- Check for circular references in comments
WITH RECURSIVE check_cycles AS (
    SELECT 
        comment_id,
        parent_comment_id,
        ARRAY[comment_id] AS path
    FROM Comments
    
    UNION ALL
    
    SELECT 
        c.comment_id,
        c.parent_comment_id,
        cc.path || c.comment_id
    FROM Comments c
    INNER JOIN check_cycles cc ON c.parent_comment_id = cc.comment_id
    WHERE NOT (c.comment_id = ANY(cc.path))
      AND array_length(cc.path, 1) < 100
)
SELECT * FROM check_cycles
WHERE comment_id = ANY(path[1:array_length(path,1)-1]);
```

---

## Monitoring and Maintenance

### Query Performance Monitoring

```sql
-- View slow queries
SELECT 
    query,
    mean_exec_time,
    calls
FROM pg_stat_statements
WHERE query LIKE '%comment_thread%' OR query LIKE '%friend_of_friend%'
ORDER BY mean_exec_time DESC
LIMIT 10;
```

### Index Usage Statistics

```sql
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE tablename IN ('Comments', 'Follows')
ORDER BY idx_scan DESC;
```

### Rebuild Indexes (Maintenance)

```sql
-- Reindex for optimal performance
REINDEX INDEX CONCURRENTLY idx_comments_parent_post;
REINDEX INDEX CONCURRENTLY idx_follows_relationships;
REINDEX INDEX CONCURRENTLY idx_follows_status;
```

---

## Version Compatibility

| PostgreSQL Version | Compatibility | Notes |
|-------------------|---------------|-------|
| 12.x | ✅ Full | All features supported |
| 13.x | ✅ Full | All features supported |
| 14.x | ✅ Full | All features supported |
| 15.x | ✅ Full | All features supported |
| 16.x | ✅ Full | All features supported |
| 11.x | ⚠️ Partial | No MATERIALIZED/NOT MATERIALIZED hints |
| 10.x and below | ❌ Not tested | May work with modifications |

---

## Security Considerations

### Function Permissions

```sql
-- Grant execute permissions to specific roles
GRANT EXECUTE ON FUNCTION get_comment_thread(INTEGER) TO app_user;
GRANT EXECUTE ON FUNCTION get_friend_of_friend_recommendations(INTEGER) TO app_user;

-- View permissions
GRANT SELECT ON comment_thread_with_metrics TO app_user;
GRANT SELECT ON advanced_friend_recommendations TO app_user;
```

### Row-Level Security

For multi-tenant applications:

```sql
-- Enable RLS on base tables
ALTER TABLE Comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE Follows ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY comment_access ON Comments
    FOR SELECT
    USING (
        user_id = current_setting('app.current_user_id')::INTEGER
        OR post_id IN (
            SELECT post_id FROM Posts
            WHERE user_id = current_setting('app.current_user_id')::INTEGER
        )
    );
```

---

## Support and Resources

- **Documentation:** See CTE_README.md for detailed usage
- **Examples:** 02_practical_examples.sql contains 15 examples
- **Testing:** 03_testing_validation.sql runs comprehensive tests
- **Quick Reference:** See CTE_QUICK_REFERENCE.sql (if available)

---

## Deployment Checklist

- [ ] PostgreSQL 12+ installed
- [ ] Database backup completed
- [ ] `setup_ctes.sql` executed successfully
- [ ] All 5 functions created
- [ ] All 2 views created
- [ ] All 3 indexes created
- [ ] `03_testing_validation.sql` passed all tests
- [ ] Sample queries return expected results
- [ ] Permissions granted to application users
- [ ] Monitoring queries configured
- [ ] Performance baseline established

---

**Deployment completed successfully!** 🎉

For questions or issues, review the troubleshooting section or consult CTE_README.md.
