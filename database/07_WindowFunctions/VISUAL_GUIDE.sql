-- ============================================================================
-- Window Functions - Visual Guide & Cheat Sheet
-- ============================================================================

/*
┌─────────────────────────────────────────────────────────────────────────────┐
│                    WINDOW FUNCTIONS AT A GLANCE                             │
└─────────────────────────────────────────────────────────────────────────────┘

BASIC SYNTAX:
┌──────────────────────────────────────────────────────────────────────────┐
│ SELECT                                                                   │
│     column1,                                                             │
│     column2,                                                             │
│     WINDOW_FUNCTION() OVER (                                            │
│         [PARTITION BY columns]                                          │
│         [ORDER BY columns]                                              │
│         [ROWS BETWEEN ... AND ...]                                      │
│     ) AS result_name                                                    │
│ FROM table_name;                                                         │
└──────────────────────────────────────────────────────────────────────────┘

*/

-- ============================================================================
-- TASK 1: ROW_NUMBER (Chronological Numbering)
-- ============================================================================
/*

┌──────────────────────────────────────────────────────────┐
│ Task: Number each user's posts sequentially (1, 2, 3...) │
└──────────────────────────────────────────────────────────┘

VISUALIZATION:

User Alice's posts:
Post 1 (Jan 1)  -->  ROW_NUMBER = 1
Post 2 (Jan 5)  -->  ROW_NUMBER = 2
Post 3 (Jan 10) -->  ROW_NUMBER = 3

User Bob's posts:
Post 1 (Jan 2)  -->  ROW_NUMBER = 1
Post 2 (Jan 8)  -->  ROW_NUMBER = 2


SYNTAX:
┌──────────────────────────────────────────────────────────┐
│ ROW_NUMBER() OVER (                                      │
│     PARTITION BY user_id        -- Separate per user    │
│     ORDER BY created_at         -- Chronological order  │
│ )                                                        │
└──────────────────────────────────────────────────────────┘

OUTPUT TABLE:
┌─────────┬────────┬─────────────┬──────────────┐
│ user_id │ post_id│ content     │ row_number   │
├─────────┼────────┼─────────────┼──────────────┤
│ 1       │ 101    │ "First"     │ 1            │
│ 1       │ 102    │ "Second"    │ 2            │
│ 1       │ 103    │ "Third"     │ 3            │
│ 2       │ 104    │ "Hi"        │ 1            │
│ 2       │ 105    │ "Bye"       │ 2            │
└─────────┴────────┴─────────────┴──────────────┘

KEY PROPERTIES:
- Always assigns 1, 2, 3... (never duplicates)
- Requires ORDER BY to be meaningful
- Always unique within partition


VIEW NAME: user_post_sequence
*/

-- ============================================================================
-- TASK 2: Running Totals (SUM with ROWS BETWEEN)
-- ============================================================================
/*

┌────────────────────────────────────────────────────────────┐
│ Task: Show cumulative post count over time per user        │
└────────────────────────────────────────────────────────────┘

VISUALIZATION:

Alice's Daily Posts:
Jan 1: 1 post  -->  Cumulative = 1
Jan 5: 2 posts -->  Cumulative = 3 (1 + 2)
Jan 10: 1 post -->  Cumulative = 4 (1 + 2 + 1)

Bob's Daily Posts:
Jan 2: 1 post  -->  Cumulative = 1
Jan 8: 3 posts -->  Cumulative = 4 (1 + 3)


SYNTAX:
┌──────────────────────────────────────────────────────────────┐
│ SUM(COUNT(*)) OVER (                                         │
│     PARTITION BY user_id                                    │
│     ORDER BY DATE(created_at)                               │
│     ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW        │
│ ) AS cumulative_posts                                       │
└──────────────────────────────────────────────────────────────┘

OUTPUT TABLE:
┌─────────┬──────────┬───────────┬──────────────┐
│ user_id │ post_date│ daily_cnt │ cumulative   │
├─────────┼──────────┼───────────┼──────────────┤
│ 1       │ 2024-01-01│ 1       │ 1            │
│ 1       │ 2024-01-05│ 2       │ 3 ← Adds up  │
│ 1       │ 2024-01-10│ 1       │ 4 ← Adds up  │
│ 2       │ 2024-01-02│ 1       │ 1            │
│ 2       │ 2024-01-08│ 3       │ 4 ← Adds up  │
└─────────┴──────────┴───────────┴──────────────┘

WINDOW FRAME EXPLAINED:
┌────────────────────────────────────────────┐
│ ROWS BETWEEN UNBOUNDED PRECEDING AND      │
│ CURRENT ROW                                │
└────────────────────────────────────────────┘

Visual:
Row 1: [*] = 1
Row 2: [*, *] = 3
Row 3: [*, *, *] = 4
Row 4: [*, *, *, *] = 4

Each row sums all rows from start to current.


VIEW NAME: daily_post_cumulative
*/

-- ============================================================================
-- TASK 3: RANK/DENSE_RANK (User Activity Rankings)
-- ============================================================================
/*

┌─────────────────────────────────────────────┐
│ Task: Rank users by number of posts         │
└─────────────────────────────────────────────┘

VISUALIZATION OF RANK vs DENSE_RANK:

5 Users with posts: 20, 20, 15, 15, 10

RANK():          DENSE_RANK():
Position 1 ✓     Position 1 ✓
Position 1 ✓     Position 1 ✓ (no gap)
Position 3 ✓     Position 2 ✓ (no gap)
Position 3 ✓     Position 2 ✓ (no gap)
Position 5 ✓     Position 3 ✓ (no gap)


SYNTAX COMPARISON:
┌─────────────────────────────────────┐
│ RANK() OVER (ORDER BY posts DESC)   │  -- Gaps: 1, 1, 3, 3, 5
│ DENSE_RANK() OVER (ORDER BY ...)    │  -- No gaps: 1, 1, 2, 2, 3
│ PERCENT_RANK() OVER (ORDER BY ...)  │  -- 0.0 to 1.0
│ NTILE(4) OVER (ORDER BY ...)        │  -- 1, 1, 2, 3, 4
└─────────────────────────────────────┘

OUTPUT TABLE:
┌─────────┬────────────┬──────┬────────────┬──────────────┐
│ username│ total_posts│ rank │ dense_rank │ percentile   │
├─────────┼────────────┼──────┼────────────┼──────────────┤
│ alice   │ 20         │ 1    │ 1          │ 1.00 (100%)  │
│ bob     │ 20         │ 1    │ 1          │ 1.00         │
│ charlie │ 15         │ 3    │ 2          │ 0.60 (60%)   │
│ diana   │ 15         │ 3    │ 2          │ 0.60         │
│ eve     │ 10         │ 5    │ 3          │ 0.00 (0%)    │
└─────────┴────────────┴──────┴────────────┴──────────────┘

Note RANK skips 3 -> 3 -> 5, but DENSE_RANK is 2 -> 2 -> 3


VIEW NAME: user_activity_ranking
*/

-- ============================================================================
-- TASK 4: LAG/LEAD (Post Comparison)
-- ============================================================================
/*

┌──────────────────────────────────────────────────────┐
│ Task: Compare each post with previous/next posts     │
└──────────────────────────────────────────────────────┘

VISUALIZATION:

Alice's posts (with time gaps):

Post 1 (Jan 1, 10:00)  <-- LAG says: NULL (no previous)
                       --> LEAD says: Post 2 (18 hours away)

Post 2 (Jan 2, 04:00)  <-- LAG says: Post 1 (18 hours ago)
                       --> LEAD says: Post 3 (24 hours away)

Post 3 (Jan 3, 04:00)  <-- LAG says: Post 2 (24 hours ago)
                       --> LEAD says: NULL (no next)


SYNTAX:
┌────────────────────────────────────────────────┐
│ LAG(post_id) OVER (                            │
│     PARTITION BY user_id                       │
│     ORDER BY created_at                        │
│ ) AS previous_post_id                          │
│                                                │
│ LEAD(post_id) OVER (                           │
│     PARTITION BY user_id                       │
│     ORDER BY created_at                        │
│ ) AS next_post_id                              │
└────────────────────────────────────────────────┘

OFFSET VARIANTS:
LAG(post_id, 1)   -- 1 row back (default)
LAG(post_id, 2)   -- 2 rows back
LEAD(post_id, 1)  -- 1 row forward
LEAD(post_id, 3)  -- 3 rows forward


OUTPUT TABLE:
┌────────┬────────────────┬──────────────┬──────────────┬───────────┐
│post_id │ created_at     │ prev_post_id │ hours_diff   │ next_post │
├────────┼────────────────┼──────────────┼──────────────┼───────────┤
│ 101    │ 2024-01-01 10  │ NULL         │ NULL         │ 102       │
│ 102    │ 2024-01-02 04  │ 101          │ 18 hours ago │ 103       │
│ 103    │ 2024-01-03 04  │ 102          │ 24 hours ago │ NULL      │
└────────┴────────────────┴──────────────┴──────────────┴───────────┘

PATTERNS DETECTED:
- Posting gap: hours_since_previous
- Consistency: Regular vs sporadic
- Trends: Engagement changes


VIEW NAME: post_comparison_analysis
*/

-- ============================================================================
-- WINDOW FUNCTION DECISION TREE
-- ============================================================================
/*

START: "What do I want to calculate?"
│
├─→ "Number rows" ? 
│   └─→ ROW_NUMBER() (1, 2, 3...)
│   └─→ RANK() (1, 1, 3...)
│   └─→ DENSE_RANK() (1, 1, 2...)
│
├─→ "Aggregate (sum, avg, count)?"
│   └─→ SUM() OVER (...)
│   └─→ AVG() OVER (...)
│   └─→ COUNT() OVER (...)
│
├─→ "Get value from another row?"
│   └─→ LAG(col) -- previous row
│   └─→ LEAD(col) -- next row
│   └─→ FIRST_VALUE(col) -- first in group
│   └─→ LAST_VALUE(col) -- last in group
│
├─→ "Show percentile/distribution?"
│   └─→ PERCENT_RANK() (0.0 to 1.0)
│   └─→ CUME_DIST() (0.0 to 1.0)
│   └─→ NTILE(4) (divide into buckets)
│
└─→ Still not sure?
    └─→ See QUICK_REFERENCE.sql or WINDOW_FUNCTIONS_README.md

ONCE YOU KNOW THE FUNCTION:
│
├─→ "Group by something?" 
│   └─→ Add: PARTITION BY column
│
├─→ "Need specific order?"
│   └─→ Add: ORDER BY column [ASC|DESC]
│
├─→ "Need specific rows?"
│   └─→ Add: ROWS BETWEEN ... AND ...
│
└─→ You have your window function!

*/

-- ============================================================================
-- PERFORMANCE VISUALIZATION
-- ============================================================================
/*

BEFORE Window Functions:
┌─────────────────────────────────────────────────────┐
│ Complex JOIN + Subquery + Self-Join              │
│ Hard to read and maintain                          │
│ Multiple table scans                               │
│ Slow performance                                   │
└─────────────────────────────────────────────────────┘

AFTER Window Functions:
┌──────────────────────────────────────────────┐
│ Single table scan + window calculation       │
│ Easy to read and understand                 │
│ Fast performance                            │
│ Maintainable code                           │
└──────────────────────────────────────────────┘


INDEXES MATTER:
┌────────────────────────────────────────────────────────┐
│ Index by PARTITION BY column:                          │
│   CREATE INDEX idx_posts_user_created                 │
│   ON Posts(user_id, created_at);                      │
│                                                        │
│ Index by ORDER BY column:                             │
│   CREATE INDEX idx_posts_created                      │
│   ON Posts(created_at);                               │
└────────────────────────────────────────────────────────┘

*/

-- ============================================================================
-- COMMON PATTERNS QUICK LOOKUP
-- ============================================================================
/*

PATTERN 1: "First N rows per group"
┌──────────────────────────────────┐
│ WITH ranked AS (                 │
│   SELECT *,                      │
│     ROW_NUMBER() OVER (          │
│       PARTITION BY group         │
│       ORDER BY value DESC        │
│     ) AS rn                      │
│   FROM table                     │
│ )                                │
│ SELECT * FROM ranked WHERE rn <= 3;  -- Top 3 per group
└──────────────────────────────────┘


PATTERN 2: "Running total"
┌──────────────────────────────────┐
│ SELECT *,                        │
│   SUM(amount) OVER (             │
│     ORDER BY date                │
│     ROWS BETWEEN UNBOUNDED      │
│       PRECEDING AND CURRENT ROW │
│   ) AS running_total             │
│ FROM transactions;               │
└──────────────────────────────────┘


PATTERN 3: "Moving average (3-period)"
┌──────────────────────────────────┐
│ SELECT *,                        │
│   AVG(value) OVER (              │
│     ORDER BY date                │
│     ROWS BETWEEN 2 PRECEDING     │
│       AND CURRENT ROW            │
│   ) AS moving_avg                │
│ FROM metrics;                    │
└──────────────────────────────────┘


PATTERN 4: "Compare to previous"
┌──────────────────────────────────┐
│ SELECT *,                        │
│   LAG(value) OVER (              │
│     ORDER BY date                │
│   ) AS prev_value,               │
│   value - LAG(value) OVER (...)  │
│     AS difference                │
│ FROM data;                       │
└──────────────────────────────────┘

*/

-- ============================================================================
-- COMMON MISTAKES AND FIXES
-- ============================================================================
/*

MISTAKE 1: Window function in WHERE clause
❌ WRONG:
   SELECT * FROM data 
   WHERE RANK() OVER (ORDER BY salary DESC) <= 10;

✅ CORRECT:
   SELECT * FROM (
     SELECT *, 
       RANK() OVER (ORDER BY salary DESC) AS rnk
     FROM data
   ) ranked
   WHERE rnk <= 10;


MISTAKE 2: Forgetting NULL defaults
❌ WRONG:
   SELECT LAG(amount) OVER (ORDER BY date)
   -- First row is NULL, might cause issues

✅ CORRECT:
   SELECT COALESCE(LAG(amount) OVER (ORDER BY date), 0)


MISTAKE 3: Unnecessary UNBOUNDED FOLLOWING
❌ SLOW:
   SUM(amount) OVER (
     ORDER BY date
     ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
   )

✅ FAST (for running totals):
   SUM(amount) OVER (
     ORDER BY date
     ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
   )


MISTAKE 4: Missing PARTITION BY
❌ WRONG (resets globally):
   SELECT 
     user_id,
     ROW_NUMBER() OVER (ORDER BY date) AS rn
   FROM posts;  -- rn: 1, 2, 3... across all users

✅ CORRECT (resets per user):
   SELECT 
     user_id,
     ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY date) AS rn
   FROM posts;  -- rn: 1, 2, 3... per user


MISTAKE 5: Missing ORDER BY
❌ WRONG:
   RANK() OVER (PARTITION BY user_id)  -- Meaningless

✅ CORRECT:
   RANK() OVER (PARTITION BY user_id ORDER BY salary DESC)

*/

-- ============================================================================
-- FILE ROADMAP
-- ============================================================================
/*

What do you want to do?              Go to file:
────────────────────────────────────────────────────────

Get started quickly?                 └─> README.md

See working examples?                └─> 02_practical_examples.sql

Need syntax reference?               └─> QUICK_REFERENCE.sql
                                       + WINDOW_FUNCTIONS_README.md

Test if it's working?                └─> 03_testing_validation.sql

Deep dive learning?                  └─> WINDOW_FUNCTIONS_README.md

Need to install?                     └─> setup_window_functions.sql

Want the full picture?               └─> IMPLEMENTATION_SUMMARY.md

*/

-- ============================================================================
-- KEY TAKEAWAYS
-- ============================================================================
/*

1. Window functions operate on a "window" of rows
2. PARTITION BY groups rows (like GROUP BY, but keeps individual rows)
3. ORDER BY determines sequence for ordering-dependent functions
4. ROWS BETWEEN specifies which rows to include in calculation
5. No GROUP BY needed when using window functions
6. Create indexes on PARTITION BY and ORDER BY columns
7. Filter before window functions for better performance
8. Window functions evaluated AFTER grouping/filtering
9. Use CTEs if you need to filter on window function results
10. Test performance with EXPLAIN ANALYZE


WINDOW FUNCTION = [Function] + PARTITION BY + ORDER BY + ROWS BETWEEN


Remember: Window functions = Easy powerful analytics without complex JOINs!

*/
