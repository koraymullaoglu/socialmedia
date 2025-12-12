# Transaction Management in PostgreSQL

## Overview

This document provides comprehensive examples of ACID-compliant transaction management patterns for the social media database. These examples demonstrate best practices for ensuring data integrity, consistency, and proper error handling in complex multi-step operations.

## Table of Contents

1. [ACID Properties](#acid-properties)
2. [Transaction Examples](#transaction-examples)
3. [Installation](#installation)
4. [Function Reference](#function-reference)
5. [Best Practices](#best-practices)
6. [Troubleshooting](#troubleshooting)

---

## ACID Properties

### Atomicity
**All-or-nothing principle**: Either all operations in a transaction succeed, or none of them do.

**Example**: When creating a community and assigning the creator as admin:
- ✓ Community is created AND creator is added as admin
- ✗ If admin assignment fails, community creation is rolled back

### Consistency
**Data integrity**: Transactions maintain database constraints and business rules.

**Examples**:
- Foreign key constraints enforced (user_id, community_id)
- Balance transfers maintain total balance (money doesn't disappear)
- Invalid data is rejected (empty posts, non-existent users)

### Isolation
**Concurrent transactions**: Transactions are isolated from each other to prevent interference.

**Isolation Levels** (from weakest to strongest):
1. **READ UNCOMMITTED**: Can see uncommitted changes (not supported in PostgreSQL)
2. **READ COMMITTED** (default): Can see committed changes between reads
3. **REPEATABLE READ**: See consistent snapshot, serialization anomalies possible
4. **SERIALIZABLE**: Complete isolation, as if transactions ran sequentially

### Durability
**Permanence**: Once committed, changes survive system crashes.

**PostgreSQL mechanisms**:
- Write-Ahead Logging (WAL)
- Crash recovery
- Point-in-time recovery

---

## Transaction Examples

### 1. Atomic Community Creation

**Purpose**: Create a community and automatically assign the creator as admin in a single atomic operation.

**File**: `06_Transactions/01_create_community_atomic.sql`

**Function**:
```sql
create_community_with_admin(
    p_creator_id INT,
    p_community_name VARCHAR(100),
    p_description TEXT,
    p_is_public BOOLEAN
) RETURNS TABLE (...)
```

**Use Case**: 
```sql
-- Success case
SELECT * FROM create_community_with_admin(
    1,
    'Photography Club',
    'Share your best photos',
    TRUE
);

-- Failure case (non-existent user)
SELECT * FROM create_community_with_admin(
    9999,  -- User doesn't exist
    'Invalid Community',
    'This will fail',
    TRUE
);
-- Result: Nothing is created, transaction rolled back
```

**Key Concepts**:
- Implicit transactions in functions
- EXCEPTION blocks for error handling
- Automatic rollback on errors

---

### 2. Post Sharing with Notifications

**Purpose**: Share a post and notify all followers. If notifications fail, the post is also rolled back.

**File**: `06_Transactions/02_post_sharing_rollback.sql`

**Functions**:
```sql
-- Main function with rollback testing
share_post_and_notify_followers(
    p_user_id INT,
    p_content TEXT,
    p_should_fail BOOLEAN DEFAULT FALSE
) RETURNS TABLE (...)

-- Production version with validation
share_post_with_validation(
    p_user_id INT,
    p_content TEXT
) RETURNS TABLE (...)
```

**Use Cases**:

```sql
-- Success case
SELECT * FROM share_post_and_notify_followers(
    1,
    'Check out my new blog post!',
    FALSE  -- Should not fail
);

-- Failure case (test rollback)
SELECT * FROM share_post_and_notify_followers(
    1,
    'This will be rolled back',
    TRUE  -- Force failure
);
-- Result: Post NOT created, notifications NOT sent
```

**Key Concepts**:
- ROLLBACK behavior
- Transactional integrity
- Pre-validation vs. rollback strategies

---

### 3. Nested Transactions (Exception Blocks)

**Purpose**: Perform batch operations where individual failures don't abort the entire transaction.

**File**: `06_Transactions/03_nested_savepoints.sql`

**Functions**:

```sql
-- Batch post creation
batch_create_posts_with_savepoints(
    p_user_id INT,
    p_posts TEXT[],
    p_continue_on_error BOOLEAN DEFAULT TRUE
) RETURNS TABLE (...)

-- Community with multiple members
create_community_with_multiple_members(
    p_creator_id INT,
    p_community_name VARCHAR(100),
    p_description TEXT,
    p_member_ids INT[]
) RETURNS TABLE (...)
```

**Use Cases**:

```sql
-- Batch post creation with some failures
SELECT * FROM batch_create_posts_with_savepoints(
    1,
    ARRAY[
        'Valid post 1',
        'Valid post 2',
        '',  -- Empty - will fail
        'Valid post 3',
        NULL,  -- NULL - will fail
        'Valid post 4'
    ]
);
-- Result: Posts 1, 2, 3, 4 created; posts 3 and 5 failed

-- Community with partial member additions
SELECT * FROM create_community_with_multiple_members(
    1,
    'Book Club',
    'Monthly discussions',
    ARRAY[2, 3, 9999, 1]  -- 9999 doesn't exist, 1 is duplicate
);
-- Result: Community created, users 2 and 3 added, others failed
```

**Key Concepts**:
- Exception blocks as implicit savepoints
- Partial failure handling
- Granular error reporting

---

### 4. Isolation Levels

**Purpose**: Demonstrate different isolation levels and their behaviors.

**File**: `06_Transactions/04_isolation_levels.sql`

**Functions**:

```sql
-- READ COMMITTED demo
demonstrate_read_committed(p_user_id INT)

-- SERIALIZABLE demo
demonstrate_serializable(p_user_id INT)

-- Phantom reads demo
demonstrate_phantom_reads(p_user_id INT)

-- Money transfer with locking
transfer_money_with_isolation(
    p_from_user_id INT,
    p_to_user_id INT,
    p_amount NUMERIC(10,2),
    p_isolation_level TEXT DEFAULT 'READ COMMITTED'
)
```

**Use Cases**:

```sql
-- READ COMMITTED (default)
SELECT * FROM demonstrate_read_committed(1);
-- Can see committed changes from other transactions

-- SERIALIZABLE (highest isolation)
SELECT * FROM demonstrate_serializable(1);
-- Complete isolation from other transactions

-- Phantom reads test
SELECT * FROM demonstrate_phantom_reads(1);
-- Shows if new rows appear between reads

-- Money transfer with row locking
SELECT * FROM transfer_money_with_isolation(1, 2, 50.00);
-- Prevents concurrent modifications with FOR UPDATE
```

**Key Concepts**:
- Isolation level selection
- Row-level locking with FOR UPDATE
- Phantom reads prevention
- Concurrent transaction handling

---

## Installation

### Quick Setup

Run the master setup script to install all transaction components and run tests:

```bash
cd /path/to/project/database
psql your_database -f setup_transactions.sql
```

### Manual Installation

Install individual components:

```bash
# 1. Atomic community creation
psql your_database -f 06_Transactions/01_create_community_atomic.sql

# 2. Post sharing with rollback
psql your_database -f 06_Transactions/02_post_sharing_rollback.sql

# 3. Nested transactions
psql your_database -f 06_Transactions/03_nested_savepoints.sql

# 4. Isolation levels
psql your_database -f 06_Transactions/04_isolation_levels.sql
```

### Verify Installation

```sql
-- Check if functions exist
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name LIKE '%community%' 
   OR routine_name LIKE '%post%';
```

---

## Function Reference

### Community Management

#### `create_community_with_admin`
Creates a community and assigns creator as admin atomically.

**Parameters**:
- `p_creator_id INT`: User ID of community creator
- `p_community_name VARCHAR(100)`: Community name
- `p_description TEXT`: Community description
- `p_is_public BOOLEAN`: Privacy setting

**Returns**: Table with community_id, creator_id, community_name, member_id, role_name, status

**Example**:
```sql
SELECT * FROM create_community_with_admin(
    1, 'Tech Enthusiasts', 'Discuss latest tech', TRUE
);
```

#### `create_community_with_multiple_members`
Creates a community and adds multiple members with partial failure support.

**Parameters**:
- `p_creator_id INT`: User ID of creator
- `p_community_name VARCHAR(100)`: Community name
- `p_description TEXT`: Description
- `p_member_ids INT[]`: Array of user IDs to add

**Returns**: Table with operation, user_id, role_name, status, message

**Example**:
```sql
SELECT * FROM create_community_with_multiple_members(
    1, 'Book Club', 'Monthly discussions', ARRAY[2, 3, 4]
);
```

---

### Post Management

#### `share_post_and_notify_followers`
Creates a post and notifies followers with rollback testing capability.

**Parameters**:
- `p_user_id INT`: User ID posting content
- `p_content TEXT`: Post content
- `p_should_fail BOOLEAN`: Test rollback (default: FALSE)

**Returns**: Table with post_id, user_id, content, notifications_sent, status

**Example**:
```sql
-- Normal post
SELECT * FROM share_post_and_notify_followers(
    1, 'Hello world!', FALSE
);

-- Test rollback
SELECT * FROM share_post_and_notify_followers(
    1, 'Test rollback', TRUE
);
```

#### `batch_create_posts_with_savepoints`
Creates multiple posts in a batch with individual error handling.

**Parameters**:
- `p_user_id INT`: User ID creating posts
- `p_posts TEXT[]`: Array of post contents
- `p_continue_on_error BOOLEAN`: Continue after failures (default: TRUE)

**Returns**: Table with post_number, post_id, content, status, error_message

**Example**:
```sql
SELECT * FROM batch_create_posts_with_savepoints(
    1,
    ARRAY['Post 1', 'Post 2', '', 'Post 3']
);
```

---

### Isolation Level Demonstrations

#### `demonstrate_read_committed`
Shows READ COMMITTED isolation level behavior.

**Parameters**:
- `p_user_id INT`: User ID for demo

**Returns**: Table with step, description, value

#### `demonstrate_serializable`
Shows SERIALIZABLE isolation level behavior.

**Parameters**:
- `p_user_id INT`: User ID for demo

**Returns**: Table with step, description, value

#### `demonstrate_phantom_reads`
Tests for phantom reads in a transaction.

**Parameters**:
- `p_user_id INT`: User ID for counting posts

**Returns**: Table with step, read_number, post_count, observation

#### `transfer_money_with_isolation`
Transfers money between accounts with proper locking.

**Parameters**:
- `p_from_user_id INT`: Sender user ID
- `p_to_user_id INT`: Receiver user ID
- `p_amount NUMERIC(10,2)`: Amount to transfer
- `p_isolation_level TEXT`: Isolation level (default: 'READ COMMITTED')

**Returns**: Table with step, from_balance, to_balance, status

**Example**:
```sql
SELECT * FROM transfer_money_with_isolation(
    1, 2, 100.00, 'SERIALIZABLE'
);
```

---

## Best Practices

### 1. Transaction Scope

**DO**:
```sql
-- Keep transactions short and focused
BEGIN;
  INSERT INTO posts (user_id, content) VALUES (1, 'Hello');
  UPDATE users SET post_count = post_count + 1 WHERE user_id = 1;
COMMIT;
```

**DON'T**:
```sql
-- Avoid long-running transactions
BEGIN;
  -- Complex analytics (takes 10 minutes)
  -- Locks tables for too long
COMMIT;
```

### 2. Error Handling

**DO**:
```sql
CREATE FUNCTION my_function() RETURNS void AS $$
BEGIN
    -- Your logic
    INSERT INTO ...;
    UPDATE ...;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error: %', SQLERRM;
        RAISE;  -- Re-raise for caller
END;
$$ LANGUAGE plpgsql;
```

**DON'T**:
```sql
-- Swallow errors silently
EXCEPTION
    WHEN OTHERS THEN
        NULL;  -- Bad: Hides problems
```

### 3. Isolation Level Selection

| Level | Use Case | Performance | Concurrency |
|-------|----------|-------------|-------------|
| READ COMMITTED | General OLTP, web apps | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| REPEATABLE READ | Reports, batch processing | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| SERIALIZABLE | Financial transactions, critical data | ⭐⭐⭐ | ⭐⭐⭐ |

**Guidelines**:
- Use READ COMMITTED (default) for most operations
- Use SERIALIZABLE for money transfers, inventory management
- Monitor for serialization failures with SERIALIZABLE

### 4. Locking Strategy

```sql
-- Explicit row locking for updates
SELECT balance FROM accounts 
WHERE user_id = 1 
FOR UPDATE;  -- Locks the row

UPDATE accounts 
SET balance = balance - 100 
WHERE user_id = 1;
```

**Locking modes**:
- `FOR UPDATE`: Exclusive lock, prevents all other locks
- `FOR SHARE`: Shared lock, allows other readers
- `FOR UPDATE SKIP LOCKED`: Skip locked rows (queue processing)

### 5. Deadlock Prevention

**DO**:
```sql
-- Always acquire locks in consistent order
BEGIN;
  SELECT * FROM users WHERE user_id = 1 FOR UPDATE;
  SELECT * FROM users WHERE user_id = 2 FOR UPDATE;
COMMIT;
```

**DON'T**:
```sql
-- Transaction A: locks 1 then 2
-- Transaction B: locks 2 then 1
-- Result: DEADLOCK!
```

---

## Troubleshooting

### Common Issues

#### 1. Serialization Failure

**Error**:
```
ERROR: could not serialize access due to concurrent update
```

**Solution**:
```sql
-- Retry the transaction
DO $$
DECLARE
    v_attempts INT := 0;
BEGIN
    LOOP
        BEGIN
            -- Your transaction here
            EXIT;  -- Success
        EXCEPTION
            WHEN serialization_failure THEN
                v_attempts := v_attempts + 1;
                IF v_attempts >= 3 THEN
                    RAISE;  -- Give up after 3 attempts
                END IF;
                PERFORM pg_sleep(0.1);  -- Wait before retry
        END;
    END LOOP;
END $$;
```

#### 2. Deadlock Detected

**Error**:
```
ERROR: deadlock detected
DETAIL: Process 1234 waits for ShareLock on transaction 5678
```

**Solution**:
- Review lock acquisition order
- Reduce transaction duration
- Use `LOCK TABLE` explicitly if needed

#### 3. Transaction Timeout

**Error**:
```
ERROR: canceling statement due to statement timeout
```

**Solution**:
```sql
-- Increase timeout for long operations
SET statement_timeout = '5min';
-- Your long transaction
RESET statement_timeout;
```

#### 4. Too Many Connections

**Error**:
```
FATAL: sorry, too many clients already
```

**Solution**:
- Use connection pooling (PgBouncer, pgpool)
- Reduce `max_connections` per app
- Monitor idle transactions

---

### Performance Monitoring

#### Check for Long-Running Transactions

```sql
SELECT 
    pid,
    usename,
    application_name,
    state,
    now() - xact_start AS duration,
    query
FROM pg_stat_activity
WHERE state != 'idle'
  AND xact_start IS NOT NULL
ORDER BY xact_start;
```

#### Check for Blocked Queries

```sql
SELECT 
    blocked_locks.pid AS blocked_pid,
    blocked_activity.usename AS blocked_user,
    blocking_locks.pid AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    blocked_activity.query AS blocked_query,
    blocking_activity.query AS blocking_query
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity 
    ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks 
    ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
    AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
    AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity 
    ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;
```

#### Monitor Transaction Commits/Rollbacks

```sql
SELECT 
    datname,
    xact_commit,
    xact_rollback,
    ROUND(100.0 * xact_rollback / NULLIF(xact_commit + xact_rollback, 0), 2) AS rollback_ratio
FROM pg_stat_database
WHERE datname = current_database();
```

---

## Testing Concurrent Transactions

### Scenario: Concurrent Money Transfers

**Terminal 1**:
```sql
BEGIN;
SELECT transfer_money_with_isolation(1, 2, 50.00);
-- Wait 5 seconds
COMMIT;
```

**Terminal 2** (while Terminal 1 is waiting):
```sql
BEGIN;
SELECT transfer_money_with_isolation(2, 1, 30.00);
-- Will wait for Terminal 1 to commit
COMMIT;
```

### Scenario: Phantom Reads

**Terminal 1**:
```sql
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT COUNT(*) FROM posts WHERE user_id = 1;
-- Note the count
-- Wait 5 seconds
SELECT COUNT(*) FROM posts WHERE user_id = 1;
-- Same count in REPEATABLE READ
COMMIT;
```

**Terminal 2** (while Terminal 1 is waiting):
```sql
INSERT INTO posts (user_id, content) VALUES (1, 'New post');
COMMIT;
-- Terminal 1 won't see this in REPEATABLE READ
```

---

## Additional Resources

### PostgreSQL Documentation
- [Transaction Isolation](https://www.postgresql.org/docs/current/transaction-iso.html)
- [Explicit Locking](https://www.postgresql.org/docs/current/explicit-locking.html)
- [PL/pgSQL Control Structures](https://www.postgresql.org/docs/current/plpgsql-control-structures.html)

### Related Database Features
- [Triggers](../02_Triggers/) - Automatic timestamp management
- [Views](../03_Views/) - Optimized query patterns
- [Full-Text Search](../05_FullTextSearch/) - Content search functionality

---

## Contributing

When adding new transaction patterns:

1. Follow the established file structure
2. Include comprehensive error handling
3. Add test cases (success and failure)
4. Document usage examples
5. Update this README

---

## License

This code is part of the Social Media Database project.

---

**Last Updated**: December 2025  
**PostgreSQL Version**: 12+  
**Author**: Database Team
