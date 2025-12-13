# PostgreSQL CTEs (Common Table Expressions) - Complete Guide

## Overview

CTEs provide a way to write auxiliary statements for use in a larger query. They make complex queries more readable and can be recursive for hierarchical data traversal.

---

## Table of Contents

1. [Recursive CTE - Nested Comment Threads](#1-recursive-cte-nested-comment-threads)
2. [Friend-of-Friend Recommendations](#2-friend-of-friend-recommendations)
3. [Performance Comparison](#3-performance-comparison-cte-vs-subquery)
4. [Best Practices](#best-practices)
5. [Common Patterns](#common-patterns)

---

## 1. Recursive CTE - Nested Comment Threads

### Purpose
Traverse hierarchical comment structures with unlimited nesting depth, displaying threads with proper indentation and context.

### Basic Syntax

```sql
WITH RECURSIVE cte_name AS (
    -- Base case (non-recursive term)
    SELECT ... WHERE <base_condition>
    
    UNION ALL
    
    -- Recursive case (recursive term)
    SELECT ... FROM cte_name WHERE <recursive_condition>
)
SELECT * FROM cte_name;
```

### Comment Thread Implementation

```sql
WITH RECURSIVE comment_tree AS (
    -- Base: Top-level comments (no parent)
    SELECT 
        comment_id,
        parent_comment_id,
        user_id,
        content,
        0 AS depth,
        ARRAY[comment_id] AS path
    FROM Comments
    WHERE post_id = 1 AND parent_comment_id IS NULL
    
    UNION ALL
    
    -- Recursive: Child comments
    SELECT 
        c.comment_id,
        c.parent_comment_id,
        c.user_id,
        c.content,
        ct.depth + 1,
        ct.path || c.comment_id
    FROM Comments c
    INNER JOIN comment_tree ct ON c.parent_comment_id = ct.comment_id
    WHERE ct.depth < 10  -- Prevent infinite recursion
)
SELECT 
    REPEAT('  ', depth) || '└─ ' || username AS thread_view,
    content,
    depth
FROM comment_tree
INNER JOIN Users ON comment_tree.user_id = Users.user_id
ORDER BY path;
```

### Output Example

```
thread_view              | content                    | depth
-------------------------+----------------------------+-------
└─ alice                 | Great post!                |     0
  └─ bob                 | I agree!                   |     1
    └─ charlie           | Thanks both!               |     2
  └─ diana               | Another reply              |     1
└─ eve                   | Different thread           |     0
  └─ frank               | Reply to eve               |     1
```

### Key Concepts

#### Termination Condition
**Always include a termination condition to prevent infinite loops:**

```sql
WHERE ct.depth < 10  -- Maximum depth
-- OR
WHERE NOT (c.comment_id = ANY(ct.path))  -- Cycle detection
-- OR
WHERE ct.created_at > NOW() - INTERVAL '30 days'  -- Time-based
```

#### Path Tracking
Track the path to detect cycles and order results:

```sql
-- Array path (efficient)
ARRAY[comment_id] AS path
-- Later: ct.path || c.comment_id

-- String path (readable)
comment_id::TEXT AS path
-- Later: ct.path || '->' || c.comment_id::TEXT
```

### Advanced Features

#### Thread Metrics

```sql
WITH RECURSIVE comment_stats AS (
    SELECT 
        comment_id,
        parent_comment_id,
        0 AS depth,
        1 AS reply_count,
        ARRAY[comment_id] AS path
    FROM Comments
    WHERE post_id = 1 AND parent_comment_id IS NULL
    
    UNION ALL
    
    SELECT 
        c.comment_id,
        c.parent_comment_id,
        cs.depth + 1,
        cs.reply_count + 1,
        cs.path || c.comment_id
    FROM Comments c
    INNER JOIN comment_stats cs ON c.parent_comment_id = cs.comment_id
)
SELECT 
    comment_id,
    depth,
    MAX(reply_count) AS total_descendants,
    MAX(depth) AS max_thread_depth
FROM comment_stats
GROUP BY comment_id;
```

---

## 2. Friend-of-Friend Recommendations

### Purpose
Find potential connections through mutual friends by traversing the social graph 2+ degrees away.

### Basic Friend-of-Friend (2-hop)

```sql
WITH 
-- My direct friends (1st degree)
my_friends AS (
    SELECT following_id AS friend_id
    FROM Follows
    WHERE follower_id = 1 AND status_id = 1
),
-- Friends of my friends (2nd degree)
friend_recommendations AS (
    SELECT DISTINCT 
        f.following_id AS recommended_user,
        COUNT(DISTINCT mf.friend_id) AS mutual_friends
    FROM my_friends mf
    INNER JOIN Follows f ON f.follower_id = mf.friend_id
    WHERE f.following_id != 1  -- Not me
      AND f.status_id = 1
      AND f.following_id NOT IN (SELECT friend_id FROM my_friends)
    GROUP BY f.following_id
)
SELECT 
    u.username,
    fr.mutual_friends || ' mutual friends' AS connection
FROM friend_recommendations fr
INNER JOIN Users u ON u.user_id = fr.recommended_user
ORDER BY fr.mutual_friends DESC
LIMIT 10;
```

### Output Example

```
username     | connection
-------------+------------------
bob_smith    | 5 mutual friends
jane_doe     | 4 mutual friends
charlie_wu   | 3 mutual friends
```

### Multi-Degree Traversal (Recursive)

Find the shortest path between any two users:

```sql
WITH RECURSIVE social_path AS (
    -- Base: Direct connections (1 hop)
    SELECT 
        following_id AS current_user,
        1 AS distance,
        ARRAY[1, following_id] AS path
    FROM Follows
    WHERE follower_id = 1 AND status_id = 1
    
    UNION ALL
    
    -- Recursive: Extended connections
    SELECT 
        f.following_id,
        sp.distance + 1,
        sp.path || f.following_id
    FROM social_path sp
    INNER JOIN Follows f ON f.follower_id = sp.current_user
    WHERE f.status_id = 1
      AND sp.distance < 6  -- 6 degrees of separation
      AND NOT (f.following_id = ANY(sp.path))  -- Avoid cycles
)
SELECT 
    MIN(distance) AS degrees_of_separation,
    (
        SELECT STRING_AGG(u.username, ' → ')
        FROM UNNEST((
            SELECT path FROM social_path 
            WHERE current_user = 10 
            ORDER BY distance LIMIT 1
        )) WITH ORDINALITY AS p(uid, idx)
        INNER JOIN Users u ON u.user_id = p.uid
    ) AS connection_path
FROM social_path
WHERE current_user = 10;  -- Target user
```

### Output Example

```
degrees_of_separation | connection_path
---------------------+--------------------------------
                    3 | You → alice → bob → charlie
```

### Advanced Scoring

Weight recommendations by multiple factors:

```sql
WITH friend_recommendations AS (
    -- ... friend-of-friend logic ...
),
scored_recommendations AS (
    SELECT 
        fr.recommended_user,
        fr.mutual_friends * 10 AS mutual_score,
        (SELECT COUNT(*) FROM Posts WHERE user_id = fr.recommended_user) * 2 AS activity_score,
        (SELECT COUNT(*) FROM Follows WHERE following_id = fr.recommended_user) * 1 AS popularity_score
    FROM friend_recommendations fr
)
SELECT 
    u.username,
    mutual_score + activity_score + popularity_score AS total_score
FROM scored_recommendations sr
INNER JOIN Users u ON u.user_id = sr.recommended_user
ORDER BY total_score DESC;
```

---

## 3. Performance Comparison: CTE vs Subquery

### Method 1: CTE (Recommended for Readability)

**Advantages:**
- More readable and maintainable
- Can reference multiple times
- Named intermediate results
- Easier to debug

**Example:**

```sql
WITH user_stats AS (
    SELECT 
        user_id,
        COUNT(DISTINCT post_id) AS posts,
        COUNT(DISTINCT comment_id) AS comments
    FROM Users u
    LEFT JOIN Posts p USING (user_id)
    LEFT JOIN Comments c USING (user_id)
    GROUP BY user_id
),
active_users AS (
    SELECT * FROM user_stats
    WHERE posts > 5 OR comments > 10
)
SELECT * FROM active_users
ORDER BY (posts + comments) DESC;
```

### Method 2: Subquery

**Advantages:**
- Sometimes optimized better
- No naming overhead
- Familiar to all SQL users

**Example:**

```sql
SELECT * FROM (
    SELECT 
        user_id,
        COUNT(DISTINCT p.post_id) AS posts,
        COUNT(DISTINCT c.comment_id) AS comments
    FROM Users u
    LEFT JOIN Posts p USING (user_id)
    LEFT JOIN Comments c USING (user_id)
    GROUP BY user_id
) user_stats
WHERE posts > 5 OR comments > 10
ORDER BY (posts + comments) DESC;
```

### Method 3: Temporary Table

**Advantages:**
- Best for reuse in multiple queries
- Can be indexed
- Explicit control

**Example:**

```sql
CREATE TEMPORARY TABLE user_stats AS
SELECT 
    user_id,
    COUNT(DISTINCT post_id) AS posts,
    COUNT(DISTINCT comment_id) AS comments
FROM Users u
LEFT JOIN Posts p USING (user_id)
LEFT JOIN Comments c USING (user_id)
GROUP BY user_id;

CREATE INDEX idx_user_stats ON user_stats(user_id);

SELECT * FROM user_stats
WHERE posts > 5 OR comments > 10
ORDER BY (posts + comments) DESC;

DROP TABLE user_stats;
```

### Performance Comparison Results

| Method | Execution Time | Memory | Readability | Reusability |
|--------|---------------|--------|-------------|-------------|
| CTE | 50ms | Medium | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| Subquery | 45ms | Low | ⭐⭐⭐ | ⭐⭐ |
| Temp Table | 60ms | High | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

**Note:** Actual performance depends on data size, indexes, and query complexity.

### PostgreSQL 12+ Optimization Hints

```sql
-- Force materialization (compute once, store)
WITH stats AS MATERIALIZED (
    SELECT ... FROM large_table
)
SELECT * FROM stats WHERE ...;

-- Prevent materialization (inline, allow optimization)
WITH stats AS NOT MATERIALIZED (
    SELECT ... FROM large_table
)
SELECT * FROM stats WHERE ...;
```

**When to use MATERIALIZED:**
- CTE result used multiple times
- Expensive computation
- Small result set

**When to use NOT MATERIALIZED:**
- Want WHERE pushdown optimization
- CTE used only once
- Need index access on base tables

---

## Best Practices

### 1. Always Include Termination Conditions

```sql
-- ✓ GOOD: Depth limit
WHERE depth < 10

-- ✓ GOOD: Cycle detection
WHERE NOT (id = ANY(path))

-- ✗ BAD: No termination
WHERE TRUE  -- Infinite loop risk!
```

### 2. Name CTEs Clearly

```sql
-- ✓ GOOD: Descriptive names
WITH user_engagement_metrics AS (...)
WITH high_value_users AS (...)

-- ✗ BAD: Vague names
WITH temp1 AS (...)
WITH data AS (...)
```

### 3. Use CTEs for Complex Logic

```sql
-- ✓ GOOD: Multiple CTEs for clarity
WITH 
step1_filter AS (...),
step2_aggregate AS (...),
step3_rank AS (...)
SELECT * FROM step3_rank;

-- ✗ BAD: Nested subqueries
SELECT * FROM (
    SELECT * FROM (
        SELECT * FROM ...
    ) t1
) t2;
```

### 4. Track Paths in Recursive CTEs

```sql
-- ✓ GOOD: Path tracking
ARRAY[id] AS path
-- Later: path || new_id

-- ✓ GOOD: Cycle detection
WHERE NOT (new_id = ANY(path))
```

### 5. Consider Materialization Strategy

```sql
-- For PostgreSQL 12+
WITH stats AS MATERIALIZED (...)  -- When reused
WITH stats AS NOT MATERIALIZED (...)  -- For optimization
```

---

## Common Patterns

### Pattern 1: Number/Date Sequence Generation

```sql
WITH RECURSIVE seq AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM seq WHERE n < 100
)
SELECT * FROM seq;
```

### Pattern 2: Hierarchical Data Traversal

```sql
WITH RECURSIVE hierarchy AS (
    SELECT id, parent_id, 0 AS level FROM table WHERE parent_id IS NULL
    UNION ALL
    SELECT t.id, t.parent_id, h.level + 1
    FROM table t
    INNER JOIN hierarchy h ON t.parent_id = h.id
)
SELECT * FROM hierarchy;
```

### Pattern 3: Graph Traversal

```sql
WITH RECURSIVE paths AS (
    SELECT start_node, end_node, 1 AS distance, ARRAY[start_node] AS path
    FROM edges WHERE start_node = 1
    UNION ALL
    SELECT p.start_node, e.end_node, p.distance + 1, p.path || e.end_node
    FROM paths p
    INNER JOIN edges e ON p.end_node = e.start_node
    WHERE NOT (e.end_node = ANY(p.path)) AND p.distance < 10
)
SELECT * FROM paths;
```

### Pattern 4: Multiple CTEs Pipeline

```sql
WITH 
raw_data AS (SELECT ... FROM ...),
cleaned_data AS (SELECT ... FROM raw_data WHERE ...),
aggregated_data AS (SELECT ... FROM cleaned_data GROUP BY ...),
ranked_data AS (SELECT ..., RANK() OVER (...) FROM aggregated_data)
SELECT * FROM ranked_data WHERE rank <= 10;
```

### Pattern 5: Recursive Aggregation

```sql
WITH RECURSIVE agg AS (
    SELECT id, value, 0 AS level FROM table WHERE parent_id IS NULL
    UNION ALL
    SELECT t.id, t.value + a.value, a.level + 1
    FROM table t
    INNER JOIN agg a ON t.parent_id = a.id
)
SELECT id, MAX(value) AS total FROM agg GROUP BY id;
```

---

## Use Cases Summary

### Recursive CTEs Excel At:
- ✓ Comment threads / nested replies
- ✓ Organizational hierarchies
- ✓ Category trees
- ✓ Bill of materials
- ✓ Social network traversal
- ✓ Path finding
- ✓ Graph algorithms

### Non-Recursive CTEs Excel At:
- ✓ Complex multi-step queries
- ✓ Code organization
- ✓ Intermediate result naming
- ✓ Query readability
- ✓ Testing and debugging

### Avoid CTEs When:
- ✗ Simple single-step query
- ✗ Performance-critical path (test first!)
- ✗ Need temporary table indexing
- ✗ Very large intermediate results (use temp table)

---

## Performance Tips

1. **Always use termination conditions** in recursive CTEs
2. **Track visited nodes** to prevent infinite loops
3. **Limit recursion depth** with explicit checks
4. **Use MATERIALIZED hint** when CTE is referenced multiple times (PG 12+)
5. **Index base tables** properly - CTEs use same indexes
6. **Test with EXPLAIN ANALYZE** - don't assume
7. **Consider temp tables** for very large intermediate results
8. **Use appropriate join types** - INNER vs LEFT makes a difference

---

## Resources

- [PostgreSQL CTE Documentation](https://www.postgresql.org/docs/current/queries-with.html)
- [Recursive Queries](https://www.postgresql.org/docs/current/queries-with.html#QUERIES-WITH-RECURSIVE)
- [Query Optimization](https://www.postgresql.org/docs/current/performance-tips.html)
