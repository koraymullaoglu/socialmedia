# PostgreSQL Window Functions - Analytical Queries

## Overview

This module implements advanced PostgreSQL window functions for social media analytics. Window functions perform calculations across a set of rows related to the current row, enabling sophisticated analytics without complex joins or subqueries.

---

## Table of Contents

1. [ROW_NUMBER: Chronological Post Numbering](#1-row_number-chronological-post-numbering)
2. [Running Totals: Daily Post Cumulative](#2-running-totals-daily-post-cumulative)
3. [RANK/DENSE_RANK: User Activity Rankings](#3-rankdense_rank-user-activity-rankings)
4. [LAG/LEAD: Post Comparison](#4-laglead-post-comparison)
5. [Advanced Analytics](#advanced-analytics)
6. [Performance Considerations](#performance-considerations)

---

## 1. ROW_NUMBER: Chronological Post Numbering

### Purpose
Assigns sequential numbers to each user's posts in chronological order, enabling:
- First post identification
- Sequential post tracking
- Pagination of user content

### View: `user_post_sequence`

```sql
CREATE OR REPLACE VIEW user_post_sequence AS
SELECT
    user_id,
    post_id,
    content,
    created_at,
    ROW_NUMBER() OVER (
        PARTITION BY user_id 
        ORDER BY created_at ASC
    ) AS post_sequence_number
FROM Posts;
```

### Key Concepts

- **PARTITION BY user_id**: Creates separate window per user
- **ORDER BY created_at ASC**: Determines sequence order
- **ROW_NUMBER()**: Assigns 1, 2, 3... (always unique, no ties)

### Sample Output

| username | post_sequence_number | content | created_at |
|----------|----------------------|---------|------------|
| john_doe | 1 | "First post!" | 2024-01-15 |
| john_doe | 2 | "Another update" | 2024-01-20 |
| jane_smith | 1 | "Hello world" | 2024-01-18 |

### Use Cases

- Track user's posting history
- Find nth post for pagination
- Identify when user started posting
- Sequential post numbering for reports

---

## 2. Running Totals: Daily Post Cumulative

### Purpose
Calculates cumulative post counts over time, showing:
- Daily post counts
- Running totals up to each day
- Average posts per day trend
- Day-to-day changes

### View: `daily_post_cumulative`

```sql
CREATE OR REPLACE VIEW daily_post_cumulative AS
SELECT
    user_id,
    DATE(created_at) AS post_date,
    COUNT(*) AS daily_post_count,
    -- Running total: cumulative posts up to this day
    SUM(COUNT(*)) OVER (
        PARTITION BY user_id
        ORDER BY DATE(created_at)
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_posts
FROM Posts
GROUP BY user_id, DATE(created_at);
```

### Key Concepts

- **SUM() OVER (...) AS window**: Aggregate function with window specification
- **PARTITION BY user_id**: Separate totals per user
- **ORDER BY post_date**: Chronological accumulation
- **ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW**: Include all rows from start to current

### Window Frame Options

```sql
-- All preceding rows (default)
ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW

-- Last 3 rows
ROWS BETWEEN 3 PRECEDING AND CURRENT ROW

-- Current row only
ROWS BETWEEN CURRENT ROW AND CURRENT ROW

-- All following rows
ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING
```

### Sample Output

| username | post_date | daily_count | cumulative | avg_per_day |
|----------|-----------|-------------|------------|------------|
| john_doe | 2024-01-15 | 2 | 2 | 2.00 |
| john_doe | 2024-01-16 | 1 | 3 | 1.50 |
| john_doe | 2024-01-17 | 3 | 6 | 2.00 |

### Use Cases

- Track user growth over time
- Identify posting trends
- Calculate running averages
- Monitor cumulative activity metrics

---

## 3. RANK/DENSE_RANK: User Activity Rankings

### Purpose
Ranks users by activity level with support for tied scores:
- **RANK()**: Handles ties by skipping numbers (1, 1, 3, 4...)
- **DENSE_RANK()**: Handles ties without skipping (1, 1, 2, 3...)
- **PERCENT_RANK()**: Percentile ranking
- **NTILE()**: Divide into quartiles/deciles

### View: `user_activity_ranking`

```sql
SELECT
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
    NTILE(4) OVER (
        ORDER BY total_posts DESC
    ) AS activity_quartile
FROM user_activity;
```

### Ranking Function Comparison

| Function | Behavior | Use Case |
|----------|----------|----------|
| ROW_NUMBER() | Always unique | Sequential numbering |
| RANK() | Skip on tie | Competitive ranking |
| DENSE_RANK() | No skip on tie | Tier-based ranking |
| PERCENT_RANK() | 0-1 percentile | Statistical ranking |
| NTILE(n) | Divide into buckets | Quartiles/Deciles |

### Sample Output (with 5 users at 10 posts each)

| rank | dense_rank | username | posts | percentile |
|------|-----------|----------|-------|-----------|
| 1 | 1 | alice | 25 | 1.00 |
| 2 | 2 | bob | 20 | 0.75 |
| 2 | 2 | charlie | 20 | 0.75 |
| 4 | 3 | diana | 15 | 0.50 |
| 5 | 4 | eve | 10 | 0.25 |

### Use Cases

- Leaderboards and rankings
- Identify top users (top 10, top 25%)
- Tiered user classifications
- Performance metrics

---

## 4. LAG/LEAD: Post Comparison

### Purpose
Access previous/next rows' data without self-joins:
- **LAG()**: Access previous row(s)
- **LEAD()**: Access next row(s)
- Compare consecutive posts
- Calculate differences and trends

### View: `post_comparison_analysis`

```sql
SELECT
    post_id,
    created_at,
    LAG(post_id, 1) OVER (
        PARTITION BY user_id
        ORDER BY created_at
    ) AS previous_post_id,
    LEAD(post_id, 1) OVER (
        PARTITION BY user_id
        ORDER BY created_at
    ) AS next_post_id,
    EXTRACT(HOUR FROM created_at - 
        LAG(created_at, 1) OVER (
            PARTITION BY user_id
            ORDER BY created_at
        )
    ) AS hours_since_previous
FROM Posts;
```

### LAG/LEAD Syntax

```sql
LAG(column, offset, default) OVER (
    PARTITION BY partition_column
    ORDER BY order_column
)

LEAD(column, offset, default) OVER (
    PARTITION BY partition_column
    ORDER BY order_column
)
```

- **column**: Value to retrieve
- **offset**: How many rows back/ahead (default 1)
- **default**: Value if no row exists (default NULL)

### Sample Output

| post_id | created_at | prev_post_id | hours_since_prev | next_post_id |
|---------|-----------|--------------|------------------|--------------|
| 101 | 2024-01-15 10:00 | NULL | NULL | 102 |
| 102 | 2024-01-15 14:00 | 101 | 4 | 103 |
| 103 | 2024-01-16 08:00 | 102 | 18 | NULL |

### Use Cases

- Posting frequency analysis
- Identify posting patterns
- Track user consistency
- Compare consecutive post engagement
- Detect activity gaps

---

## Advanced Analytics

### Posting Consistency Metrics

Combines multiple window functions to analyze posting behavior:

```sql
SELECT
    username,
    post_count,
    avg_hours_between_posts,
    STDDEV(hours_gap) AS posting_consistency_score,
    posts_per_day,
    RANK() OVER (
        ORDER BY STDDEV(hours_gap) ASC
    ) AS consistency_rank
FROM posting_data;
```

**Consistency Score**:
- Low STDDEV = Consistent posting
- High STDDEV = Irregular posting

### Post Engagement Trends

Tracks engagement metrics with moving averages:

```sql
SELECT
    post_id,
    like_count,
    LAG(like_count) OVER (
        PARTITION BY user_id
        ORDER BY created_at
    ) AS previous_likes,
    AVG(like_count) OVER (
        PARTITION BY user_id
        ORDER BY created_at
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS moving_avg_3_posts
FROM post_engagement;
```

---

## Performance Considerations

### Indexing Strategy

Create indexes to optimize window function queries:

```sql
-- Index for partitioning
CREATE INDEX idx_posts_user_created 
ON Posts(user_id, created_at);

-- Index for aggregations
CREATE INDEX idx_posts_created 
ON Posts(created_at);

-- Composite index for filtering
CREATE INDEX idx_posts_user_deleted_created 
ON Posts(user_id, deleted_at, created_at);
```

### Query Optimization Tips

1. **Filter before window functions** - Use WHERE before partitioning
2. **Avoid unnecessary partitions** - Only PARTITION BY when needed
3. **Order deterministically** - Always ORDER BY in window frame
4. **Materialize views** - Create materialized views for complex queries
5. **Batch calculations** - Use single query with multiple window functions

### Example: Optimized Query

```sql
-- Bad: Processes all posts
SELECT
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at)
FROM Posts
WHERE created_at > NOW() - INTERVAL '30 days';

-- Good: Window function on already-filtered set
WITH recent_posts AS (
    SELECT post_id, user_id, created_at
    FROM Posts
    WHERE created_at > NOW() - INTERVAL '30 days'
)
SELECT
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at)
FROM recent_posts;
```

---

## Common Window Function Patterns

### 1. Year-over-Year Comparison

```sql
SELECT
    DATE_TRUNC('month', created_at) AS month,
    COUNT(*) AS posts,
    LAG(COUNT(*), 12) OVER (
        ORDER BY DATE_TRUNC('month', created_at)
    ) AS posts_same_month_last_year
FROM Posts
GROUP BY DATE_TRUNC('month', created_at);
```

### 2. Running Percentage

```sql
SELECT
    post_id,
    like_count,
    SUM(like_count) OVER (
        PARTITION BY user_id
    ) / SUM(like_count) OVER () * 100 AS percentage_of_total
FROM Posts;
```

### 3. Cumulative Product

```sql
SELECT
    date,
    value,
    EXP(SUM(LN(value)) OVER (
        ORDER BY date
    )) AS cumulative_product
FROM metrics;
```

### 4. First/Last Value in Window

```sql
SELECT
    post_id,
    created_at,
    FIRST_VALUE(created_at) OVER (
        PARTITION BY user_id
        ORDER BY created_at
    ) AS user_first_post,
    LAST_VALUE(created_at) OVER (
        PARTITION BY user_id
        ORDER BY created_at
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS user_last_post
FROM Posts;
```

---

## Testing Window Functions

Run these queries to test implementations:

```sql
-- Test 1: Verify post sequence numbers
SELECT * FROM user_post_sequence 
WHERE user_id = 1
ORDER BY post_sequence_number;

-- Test 2: Check cumulative totals
SELECT * FROM daily_post_cumulative
WHERE user_id = 1
ORDER BY post_date;

-- Test 3: View rankings
SELECT * FROM user_activity_ranking
WHERE post_rank <= 10;

-- Test 4: Compare post timeline
SELECT * FROM post_comparison_analysis
WHERE user_id = 1
LIMIT 10;
```

---

## Resources

- [PostgreSQL Window Functions Documentation](https://www.postgresql.org/docs/current/functions-window.html)
- [Window Functions in SQL](https://www.postgresql.org/docs/current/sql-expressions.html#syntax-window-functions)
- [Performance Tuning](https://www.postgresql.org/docs/current/performance-tips.html)
