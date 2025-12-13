-- ============================================================================
-- Window Functions - Quick Reference Guide
-- ============================================================================
-- A handy reference for PostgreSQL window function syntax and patterns
-- ============================================================================

-- BASIC WINDOW FUNCTION SYNTAX
-- ============================================================================
/*
SELECT
    column1,
    column2,
    window_function() OVER (
        [PARTITION BY partition_column]
        [ORDER BY order_column [ASC|DESC]]
        [ROWS|RANGE frame_specification]
    ) AS result_name
FROM table_name;
*/


-- WINDOW FUNCTIONS QUICK REFERENCE
-- ============================================================================

-- 1. NUMBERING FUNCTIONS
-- ============================================================================
ROW_NUMBER()              -- Sequential numbering (1, 2, 3...) always unique
RANK()                    -- Ranking with gaps on ties (1, 1, 3, 4...)
DENSE_RANK()              -- Ranking without gaps (1, 1, 2, 3...)
NTILE(n)                  -- Divide into n buckets (quartiles, deciles, etc.)

-- Examples:
-- ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at)
-- RANK() OVER (ORDER BY total_posts DESC)
-- DENSE_RANK() OVER (PARTITION BY category ORDER BY sales DESC)
-- NTILE(4) OVER (ORDER BY salary)


-- 2. AGGREGATE WINDOW FUNCTIONS
-- ============================================================================
SUM(column)               -- Running/cumulative sum
AVG(column)               -- Average within window
COUNT(column)             -- Count within window
MIN(column)               -- Minimum value in window
MAX(column)               -- Maximum value in window
STDDEV(column)            -- Standard deviation in window
VAR_POP(column)           -- Population variance in window
VAR_SAMP(column)          -- Sample variance in window

-- Examples:
-- SUM(amount) OVER (PARTITION BY user_id ORDER BY created_at)
-- AVG(likes) OVER (PARTITION BY user_id)
-- COUNT(*) OVER (PARTITION BY category)


-- 3. POSITIONAL FUNCTIONS
-- ============================================================================
FIRST_VALUE(column)       -- First value in window frame
LAST_VALUE(column)        -- Last value in window frame
NTH_VALUE(column, n)      -- Nth value in window frame
LAG(column, offset, default)    -- Access previous row
LEAD(column, offset, default)   -- Access next row

-- Examples:
-- FIRST_VALUE(salary) OVER (ORDER BY hire_date)
-- LAST_VALUE(created_at) OVER (ORDER BY created_at ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
-- LAG(price, 1) OVER (PARTITION BY product_id ORDER BY date)
-- LEAD(value, 2, 0) OVER (PARTITION BY id ORDER BY date)


-- 4. STATISTICAL FUNCTIONS
-- ============================================================================
PERCENT_RANK()            -- Percentile (0.0 to 1.0)
CUME_DIST()               -- Cumulative distribution (0.0 to 1.0)

-- Examples:
-- PERCENT_RANK() OVER (ORDER BY salary DESC)
-- CUME_DIST() OVER (ORDER BY score)


-- COMMON WINDOW FRAME SPECIFICATIONS
-- ============================================================================

-- Default Frame (with ORDER BY, includes order position)
-- ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW

ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
-- All rows from start to current row (cumulative)

ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
-- All rows in partition (use with LAST_VALUE, FIRST_VALUE)

ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
-- Current row plus one before and one after (3-row window)

ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
-- Last 2 rows plus current (3-row moving window)

RANGE BETWEEN INTERVAL '7 days' PRECEDING AND CURRENT ROW
-- All rows within 7 days before current row


-- PARTITION BY vs ORDER BY
-- ============================================================================

-- PARTITION BY ONLY (no ORDER BY)
-- - Window includes all rows in partition
-- - Aggregate functions return same value for all rows

SELECT
    user_id,
    post_id,
    COUNT(*) OVER (PARTITION BY user_id) AS total_user_posts
FROM Posts;
-- Result: Each row shows total posts by that user


-- ORDER BY ONLY (no PARTITION BY)
-- - Window includes all rows in table
-- - Creates running totals from start to current

SELECT
    post_id,
    created_at,
    COUNT(*) OVER (ORDER BY created_at) AS cumulative_posts
FROM Posts;
-- Result: Running total of all posts in order


-- PARTITION BY AND ORDER BY
-- - Window partitioned, then ordered within partition
-- - Most common pattern for analytics

SELECT
    user_id,
    post_id,
    created_at,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at) AS post_num
FROM Posts;
-- Result: Post sequence number per user


-- REAL-WORLD PATTERNS
-- ============================================================================

-- Pattern 1: Rank with Ties
SELECT
    product_id,
    sales,
    RANK() OVER (ORDER BY sales DESC) AS rank,
    DENSE_RANK() OVER (ORDER BY sales DESC) AS dense_rank
FROM products;


-- Pattern 2: Running Total
SELECT
    date,
    amount,
    SUM(amount) OVER (
        ORDER BY date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total
FROM transactions;


-- Pattern 3: Moving Average (3-period)
SELECT
    date,
    value,
    ROUND(AVG(value) OVER (
        ORDER BY date
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS moving_avg_3
FROM metrics;


-- Pattern 4: Compare to Previous Row
SELECT
    date,
    sales,
    LAG(sales) OVER (ORDER BY date) AS prev_day_sales,
    sales - LAG(sales) OVER (ORDER BY date) AS day_change,
    ROUND(100.0 * (sales - LAG(sales) OVER (ORDER BY date)) 
          / LAG(sales) OVER (ORDER BY date), 2) AS pct_change
FROM daily_sales;


-- Pattern 5: Percentile Ranking
SELECT
    employee_id,
    salary,
    ROUND(PERCENT_RANK() OVER (ORDER BY salary DESC) * 100, 2) AS percentile
FROM employees;


-- Pattern 6: Top N per Group
SELECT *
FROM (
    SELECT
        category,
        product_id,
        sales,
        ROW_NUMBER() OVER (PARTITION BY category ORDER BY sales DESC) AS rank
    FROM products
) ranked
WHERE rank <= 3;


-- Pattern 7: First and Last Values
SELECT
    user_id,
    date,
    amount,
    FIRST_VALUE(amount) OVER (
        PARTITION BY user_id
        ORDER BY date
    ) AS first_amount,
    LAST_VALUE(amount) OVER (
        PARTITION BY user_id
        ORDER BY date
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS last_amount
FROM transactions;


-- Pattern 8: Year-over-Year Comparison
SELECT
    date,
    sales,
    LAG(sales, 12) OVER (
        ORDER BY DATE_TRUNC('month', date)
    ) AS sales_12_months_ago,
    ROUND(100.0 * (sales - LAG(sales, 12) OVER (ORDER BY DATE_TRUNC('month', date)))
          / LAG(sales, 12) OVER (ORDER BY DATE_TRUNC('month', date)), 2) AS yoy_growth
FROM monthly_sales;


-- PERFORMANCE OPTIMIZATION TIPS
-- ============================================================================

-- ✓ DO: Create indexes for PARTITION BY and ORDER BY columns
CREATE INDEX idx_user_created ON posts(user_id, created_at);

-- ✓ DO: Filter data before window functions
WITH filtered AS (
    SELECT * FROM sales WHERE year = 2024
)
SELECT
    region,
    amount,
    SUM(amount) OVER (PARTITION BY region) AS region_total
FROM filtered;

-- ✗ DON'T: Use window functions in WHERE clause
-- Window functions are evaluated AFTER grouping
-- ✓ DO: Use subquery or CTE if you need to filter on window function results
WITH ranked AS (
    SELECT
        product_id,
        RANK() OVER (ORDER BY sales DESC) AS rank
    FROM products
)
SELECT * FROM ranked WHERE rank <= 10;

-- ✗ DON'T: Over-specify window frames
-- Default is usually fine
SELECT AVG(salary) OVER (PARTITION BY dept_id ORDER BY salary)
FROM employees;

-- ✓ DO: Be explicit when you need specific frame
SELECT AVG(salary) OVER (
    PARTITION BY dept_id
    ORDER BY salary
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
) AS dept_avg
FROM employees;


-- COMMON MISTAKES AND FIXES
-- ============================================================================

-- Mistake 1: Forgetting to handle NULL values
-- ✗ WRONG
SELECT LAG(value) OVER (ORDER BY date) FROM data;

-- ✓ CORRECT
SELECT COALESCE(LAG(value) OVER (ORDER BY date), 0) FROM data;


-- Mistake 2: Window function in WHERE clause
-- ✗ WRONG
SELECT * FROM sales 
WHERE RANK() OVER (ORDER BY amount DESC) <= 10;

-- ✓ CORRECT
SELECT * FROM (
    SELECT
        *,
        RANK() OVER (ORDER BY amount DESC) AS rank
    FROM sales
) ranked
WHERE rank <= 10;


-- Mistake 3: Incorrect frame specification
-- ✗ WRONG - doesn't include all rows
SELECT
    date,
    sales,
    LAST_VALUE(sales) OVER (
        PARTITION BY region
        ORDER BY date
    ) AS last_sale
FROM sales;

-- ✓ CORRECT - includes all rows in partition
SELECT
    date,
    sales,
    LAST_VALUE(sales) OVER (
        PARTITION BY region
        ORDER BY date
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS last_sale
FROM sales;


-- Mistake 4: Missing PARTITION BY when needed
-- ✗ WRONG - ROW_NUMBER continues globally
SELECT
    user_id,
    ROW_NUMBER() OVER (ORDER BY created_at)
FROM posts;

-- ✓ CORRECT - ROW_NUMBER resets per user
SELECT
    user_id,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at)
FROM posts;


-- QUERY BUILDING CHECKLIST
-- ============================================================================

-- When writing a window function query, ask:
-- 
-- 1. What calculation do I need?
--    → Choose window function (ROW_NUMBER, RANK, SUM, AVG, LAG, etc.)
--
-- 2. How should rows be grouped?
--    → Set PARTITION BY clause (or leave empty for all rows)
--
-- 3. What order matters?
--    → Set ORDER BY clause (required for most functions)
--
-- 4. What rows should be included in the calculation?
--    → Set ROWS/RANGE frame (default often works)
--
-- 5. Do I need to filter results?
--    → Wrap in subquery/CTE and filter on window function result
--
-- 6. Will this be performant?
--    → Check indexes exist for PARTITION BY and ORDER BY columns


-- USEFUL RESOURCES
-- ============================================================================
/*
Official PostgreSQL Documentation:
https://www.postgresql.org/docs/current/functions-window.html

Window Function Types:
- Numbering: ROW_NUMBER, RANK, DENSE_RANK, NTILE
- Aggregate: SUM, AVG, COUNT, MIN, MAX, STDDEV, VAR_POP, VAR_SAMP
- Positional: FIRST_VALUE, LAST_VALUE, NTH_VALUE, LAG, LEAD
- Statistical: PERCENT_RANK, CUME_DIST

Frame Clause Keywords:
- ROWS: Physical row range
- RANGE: Logical range based on values
- UNBOUNDED PRECEDING: From start of partition
- UNBOUNDED FOLLOWING: To end of partition
- CURRENT ROW: Current row
- n PRECEDING/FOLLOWING: n rows before/after

Common Use Cases:
- Running totals and cumulative calculations
- Year-over-year or period-over-period comparisons
- Ranking and percentile calculations
- Moving averages and trend analysis
- Identifying duplicates and anomalies
- Gap and island detection
*/
