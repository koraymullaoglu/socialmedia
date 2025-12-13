# PostgreSQL Window Functions Module

## Overview

This module provides comprehensive implementation of PostgreSQL window functions for advanced analytics on your social media platform. Window functions enable sophisticated data analysis without complex joins or subqueries.

## 📋 Contents

### Files Included

1. **01_analytical_queries.sql** - Complete implementation of all window function views
   - ROW_NUMBER for post sequencing
   - Running totals with SUM window
   - RANK/DENSE_RANK for user rankings
   - LAG/LEAD for post comparison
   - Advanced consistency and engagement metrics

2. **02_practical_examples.sql** - Runnable examples with expected outputs
   - Sample data setup instructions
   - 11 detailed examples demonstrating each function
   - Real-world query patterns
   - Performance optimization tips

3. **03_testing_validation.sql** - Complete test suite
   - 11 comprehensive test scenarios
   - Data quality validation
   - Performance benchmarking
   - Real-world query examples

4. **setup_window_functions.sql** - Installation script
   - Creates all views automatically
   - Sets up performance indexes
   - Grants proper permissions
   - Verification output

5. **WINDOW_FUNCTIONS_README.md** - Detailed documentation
   - Explanation of each window function type
   - Syntax reference
   - Common patterns
   - Performance considerations

6. **QUICK_REFERENCE.sql** - Handy syntax guide
   - Function definitions
   - Common patterns
   - Mistakes to avoid
   - Query building checklist

## 🚀 Quick Start

### Installation

```bash
# Using psql command line
psql -U your_username -d your_database -f database/07_WindowFunctions/setup_window_functions.sql

# Or within psql
\i database/07_WindowFunctions/setup_window_functions.sql
```

### Immediate Usage

```sql
-- View your posts ranked chronologically
SELECT * FROM user_post_sequence 
WHERE user_id = 1;

-- See daily posting activity with running totals
SELECT * FROM daily_post_cumulative 
WHERE user_id = 1
ORDER BY post_date;

-- Rank users by activity level
SELECT * FROM user_activity_ranking 
ORDER BY post_rank LIMIT 10;

-- Compare consecutive posts
SELECT * FROM post_comparison_analysis 
WHERE user_id = 1
ORDER BY created_at;
```

## 📊 Window Functions Implemented

### 1. ROW_NUMBER - Chronological Numbering
**View**: `user_post_sequence`

Assigns sequential numbers to each user's posts in chronological order.

```sql
SELECT
    username,
    post_sequence_number,
    content,
    created_at
FROM user_post_sequence
WHERE post_sequence_number <= 5;
```

**Use Cases**:
- Identify first/last posts
- Paginate user content
- Track posting history

---

### 2. Running Totals - Cumulative Calculations
**View**: `daily_post_cumulative`

Shows cumulative post counts over time with moving averages.

```sql
SELECT
    username,
    post_date,
    daily_post_count,
    cumulative_posts,
    average_posts_per_day
FROM daily_post_cumulative
WHERE post_date >= NOW() - INTERVAL '30 days';
```

**Use Cases**:
- Track growth over time
- Calculate trends
- Monitor cumulative metrics

---

### 3. RANK/DENSE_RANK - User Rankings
**View**: `user_activity_ranking`

Ranks users by activity with support for tied scores using RANK, DENSE_RANK, PERCENT_RANK, and NTILE.

```sql
SELECT
    post_rank,
    username,
    total_posts,
    activity_quartile
FROM user_activity_ranking
WHERE post_rank <= 25;
```

**Use Cases**:
- Leaderboards
- Identify top users
- Segment users into tiers

---

### 4. LAG/LEAD - Post Comparison
**View**: `post_comparison_analysis`

Compares consecutive posts to analyze posting patterns and time gaps.

```sql
SELECT
    username,
    post_id,
    created_at,
    hours_since_previous,
    hours_until_next
FROM post_comparison_analysis
WHERE hours_since_previous IS NOT NULL;
```

**Use Cases**:
- Detect posting patterns
- Calculate time gaps
- Identify consistency

---

### 5. Advanced Analytics

#### Posting Consistency Metrics
Analyzes posting frequency and pattern consistency.

```sql
SELECT
    username,
    post_count,
    posts_per_day,
    posting_consistency_score,
    consistency_rank
FROM posting_consistency_metrics
WHERE consistency_rank <= 20;
```

#### Post Engagement Trends
Tracks engagement changes and moving averages.

```sql
SELECT
    username,
    post_id,
    like_count,
    engagement_change,
    moving_avg_likes_3post
FROM post_engagement_trends
WHERE engagement_change != 0;
```

---

## 🎯 Key Features

### Window Function Types Supported

| Function | Purpose | Example |
|----------|---------|---------|
| ROW_NUMBER() | Sequential numbering | Assign 1, 2, 3... |
| RANK() | Competitive ranking | Handle ties with gaps |
| DENSE_RANK() | Dense ranking | Handle ties without gaps |
| PERCENT_RANK() | Percentile ranking | 0.0 to 1.0 scale |
| CUME_DIST() | Cumulative distribution | Show tier positioning |
| NTILE(n) | Divide into buckets | Create quartiles |
| SUM/AVG/COUNT/etc | Aggregate with window | Running totals |
| FIRST_VALUE/LAST_VALUE | Positional access | Get first/last in frame |
| LAG/LEAD | Access other rows | Compare consecutive rows |

### Performance Optimizations

- **Indexed columns**: Automatic index creation on PARTITION BY and ORDER BY columns
- **Efficient queries**: CTEs for filtering before window functions
- **Materialized options**: Can create materialized views for frequent queries
- **Proper framing**: Optimized window frame specifications

---

## 📈 Real-World Examples

### Find Top 10 Most Active Users with Recent Activity

```sql
SELECT
    u.username,
    uar.post_rank,
    uar.total_posts,
    MAX(p.created_at) AS last_post_date,
    CASE
        WHEN MAX(p.created_at) >= NOW() - INTERVAL '7 days' THEN 'Active'
        WHEN MAX(p.created_at) >= NOW() - INTERVAL '30 days' THEN 'Recent'
        ELSE 'Inactive'
    END AS status
FROM users u
INNER JOIN user_activity_ranking uar ON u.user_id = uar.user_id
LEFT JOIN posts p ON u.user_id = p.user_id
WHERE uar.post_rank <= 10
GROUP BY u.user_id, u.username, uar.post_rank, uar.total_posts
ORDER BY uar.post_rank;
```

### Detect Posting Pattern Changes

```sql
SELECT
    u.username,
    pca.post_id,
    pca.created_at,
    pca.hours_since_previous,
    CASE
        WHEN pca.hours_since_previous IS NULL THEN 'First post'
        WHEN pca.hours_since_previous < 4 THEN 'Very active'
        WHEN pca.hours_since_previous < 24 THEN 'Active'
        WHEN pca.hours_since_previous < 168 THEN 'Weekly'
        ELSE 'Sporadic'
    END AS posting_pattern
FROM post_comparison_analysis pca
INNER JOIN users u ON pca.user_id = u.user_id
WHERE pca.hours_since_previous IS NOT NULL
ORDER BY u.username, pca.created_at;
```

### Analyze Engagement Trends

```sql
SELECT
    u.username,
    pet.post_id,
    pet.like_count,
    pet.moving_avg_likes_3post,
    CASE
        WHEN pet.engagement_change > 0 THEN '📈 Growing'
        WHEN pet.engagement_change < 0 THEN '📉 Declining'
        ELSE '→ Stable'
    END AS trend
FROM post_engagement_trends pet
INNER JOIN users u ON pet.user_id = u.user_id
WHERE pet.previous_like_count IS NOT NULL
ORDER BY ABS(pet.engagement_change) DESC
LIMIT 20;
```

---

## 🧪 Testing

Run the complete test suite to validate all implementations:

```bash
psql -U your_username -d your_database -f database/07_WindowFunctions/03_testing_validation.sql
```

Tests included:
- ✓ View availability verification
- ✓ ROW_NUMBER correctness (no duplicates)
- ✓ Running total monotonicity
- ✓ RANK vs DENSE_RANK comparison
- ✓ LAG/LEAD NULL handling
- ✓ Consistency metrics validation
- ✓ Performance benchmarking
- ✓ Data quality checks
- ✓ Real-world query examples

---

## 📚 Documentation

### Files to Read

1. **WINDOW_FUNCTIONS_README.md** - Start here for detailed explanations
2. **02_practical_examples.sql** - See working examples with output
3. **QUICK_REFERENCE.sql** - Handy syntax reference
4. **03_testing_validation.sql** - Run tests to validate

### Key Concepts

#### PARTITION BY
Divides rows into groups (like GROUP BY, but keeps individual rows)

```sql
PARTITION BY user_id  -- Separate calculation per user
PARTITION BY category -- Separate calculation per category
```

#### ORDER BY
Determines sequence for ordering-dependent functions

```sql
ORDER BY created_at      -- Chronological order
ORDER BY salary DESC     -- Highest to lowest
ORDER BY created_at ASC  -- Oldest to newest
```

#### Frame Specifications
Determines which rows are included in calculation

```sql
ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW  -- Running total
ROWS BETWEEN 2 PRECEDING AND CURRENT ROW          -- 3-row moving window
ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING  -- All rows
```

---

## ⚡ Performance Tips

1. **Always index PARTITION BY columns**
   ```sql
   CREATE INDEX idx_posts_user_created ON Posts(user_id, created_at);
   ```

2. **Filter before window functions**
   ```sql
   WITH filtered AS (
       SELECT * FROM Posts WHERE deleted_at IS NULL
   )
   SELECT ... FROM filtered;
   ```

3. **Use appropriate window frames**
   ```sql
   -- Good: Explicit frame
   SUM(amount) OVER (
       PARTITION BY user_id
       ORDER BY date
       ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
   )
   
   -- Avoid: Unnecessary UNBOUNDED FOLLOWING
   SUM(amount) OVER (
       PARTITION BY user_id
       ORDER BY date
       ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
   )
   ```

4. **Analyze with EXPLAIN**
   ```sql
   EXPLAIN ANALYZE
   SELECT ... FROM user_post_sequence;
   ```

---

## 🔧 Troubleshooting

### View not found
```sql
-- Reinstall setup script
psql -U your_username -d your_database -f setup_window_functions.sql
```

### Query running slowly
```sql
-- Check if indexes exist
SELECT * FROM pg_indexes 
WHERE tablename IN ('posts', 'users', 'post_likes');

-- Run ANALYZE to update statistics
ANALYZE Posts;
ANALYZE Users;
ANALYZE Post_Likes;
```

### Results don't match expectations
```sql
-- Run validation tests
psql -U your_username -d your_database -f 03_testing_validation.sql
```

---

## 📖 Additional Resources

- [PostgreSQL Window Functions Documentation](https://www.postgresql.org/docs/current/functions-window.html)
- [Window Functions in Detail](https://www.postgresql.org/docs/current/sql-expressions.html#syntax-window-functions)
- [Performance Tuning Guide](https://www.postgresql.org/docs/current/performance-tips.html)

---

## 📝 Summary

This module implements all four requested window function tasks:

✅ **Task 1**: Chronological numbering of user posts (ROW_NUMBER)
- View: `user_post_sequence`
- Assigns 1, 2, 3... to each user's posts

✅ **Task 2**: Running total of daily post counts (SUM with ROWS BETWEEN)
- View: `daily_post_cumulative`
- Cumulative totals with daily averages

✅ **Task 3**: Most active users ranking (RANK/DENSE_RANK)
- View: `user_activity_ranking`
- Multiple ranking methods and percentiles

✅ **Task 4**: Post comparison using LAG/LEAD
- View: `post_comparison_analysis`
- Compare with previous/next posts

**Plus extras**:
- Posting consistency metrics
- Engagement trend analysis
- Complete test suite
- Performance optimization

---

## 🎓 Next Steps

1. **Run setup**: `psql -U username -d dbname -f setup_window_functions.sql`
2. **Test**: `psql -U username -d dbname -f 03_testing_validation.sql`
3. **Explore**: Try the examples in `02_practical_examples.sql`
4. **Integrate**: Use views in your application queries
5. **Monitor**: Watch performance with `EXPLAIN ANALYZE`

---

**Ready to use!** All window functions are installed and ready for production analytics queries.
