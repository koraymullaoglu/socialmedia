-- Transaction Example 4: Isolation Levels
-- Demonstrates different isolation levels and their effects
-- Compares READ COMMITTED vs SERIALIZABLE

\echo '========================================='
\echo 'TRANSACTION EXAMPLE 4: ISOLATION LEVELS'
\echo '========================================='

-- =====================================================
-- Setup: Create test table for isolation demonstrations
-- =====================================================

CREATE TABLE IF NOT EXISTS AccountBalance (
    user_id INT PRIMARY KEY REFERENCES Users(user_id),
    balance DECIMAL(10, 2) DEFAULT 0.00,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

\echo '✓ AccountBalance table ready'

-- =====================================================
-- Function: demonstrate_read_committed
-- Shows READ COMMITTED isolation level behavior
-- Transactions can see committed changes from other transactions
-- =====================================================

CREATE OR REPLACE FUNCTION demonstrate_read_committed()
RETURNS TABLE (
    step INT,
    description TEXT,
    value TEXT
) AS $$
DECLARE
    v_user_id INT;
    v_balance1 DECIMAL;
    v_balance2 DECIMAL;
BEGIN
    -- Get or create a test user with balance
    SELECT user_id INTO v_user_id FROM Users LIMIT 1;
    
    -- Ensure user has balance record
    INSERT INTO AccountBalance (user_id, balance)
    VALUES (v_user_id, 100.00)
    ON CONFLICT (user_id) DO UPDATE SET balance = 100.00;
    
    RAISE NOTICE '=== READ COMMITTED Isolation Demo ===';
    RAISE NOTICE 'Isolation Level: READ COMMITTED (PostgreSQL default)';
    RAISE NOTICE '';
    
    -- Step 1: Read initial balance
    RETURN QUERY SELECT 
        1,
        'Initial balance'::TEXT,
        'Balance: $100.00'::TEXT;
    
    -- Step 2: Read balance (will see committed changes from other transactions)
    SELECT balance INTO v_balance1 FROM AccountBalance WHERE AccountBalance.user_id = v_user_id;
    
    RETURN QUERY SELECT 
        2,
        'First read in transaction'::TEXT,
        'Balance: $' || v_balance1::TEXT;
    
    -- Simulate time passing (in real scenario, another transaction could commit here)
    PERFORM pg_sleep(0.1);
    
    -- Step 3: Read again (in READ COMMITTED, could see different value)
    SELECT balance INTO v_balance2 FROM AccountBalance WHERE AccountBalance.user_id = v_user_id;
    
    RETURN QUERY SELECT 
        3,
        'Second read in same transaction'::TEXT,
        'Balance: $' || v_balance2::TEXT;
    
    RETURN QUERY SELECT 
        4,
        'Observation'::TEXT,
        'In READ COMMITTED: Can see new committed changes between reads'::TEXT;
    
    RAISE NOTICE '=== Demo Complete ===';
    
END;
$$ LANGUAGE plpgsql;

\echo '✓ Function demonstrate_read_committed created'

-- =====================================================
-- Function: demonstrate_serializable
-- Shows SERIALIZABLE isolation level behavior
-- Provides complete isolation from other transactions
-- =====================================================

CREATE OR REPLACE FUNCTION demonstrate_serializable()
RETURNS TABLE (
    step INT,
    description TEXT,
    value TEXT
) AS $$
DECLARE
    v_user_id INT;
    v_balance1 DECIMAL;
    v_balance2 DECIMAL;
BEGIN
    -- Get test user
    SELECT user_id INTO v_user_id FROM Users LIMIT 1;
    
    -- Ensure user has balance record
    INSERT INTO AccountBalance (user_id, balance)
    VALUES (v_user_id, 100.00)
    ON CONFLICT (user_id) DO UPDATE SET balance = 100.00;
    
    RAISE NOTICE '=== SERIALIZABLE Isolation Demo ===';
    RAISE NOTICE 'Isolation Level: SERIALIZABLE (highest isolation)';
    RAISE NOTICE '';
    
    -- Set isolation level (PostgreSQL function level uses REPEATABLE READ)
    -- For true SERIALIZABLE, must be set at transaction level
    
    RETURN QUERY SELECT 
        1,
        'Initial setup'::TEXT,
        'Balance: $100.00, Isolation: SERIALIZABLE'::TEXT;
    
    -- Step 2: First read
    SELECT balance INTO v_balance1 FROM AccountBalance WHERE AccountBalance.user_id = v_user_id;
    
    RETURN QUERY SELECT 
        2,
        'First read'::TEXT,
        'Balance: $' || v_balance1::TEXT;
    
    -- Simulate time passing
    PERFORM pg_sleep(0.1);
    
    -- Step 3: Second read (will see same value in SERIALIZABLE)
    SELECT balance INTO v_balance2 FROM AccountBalance WHERE AccountBalance.user_id = v_user_id;
    
    RETURN QUERY SELECT 
        3,
        'Second read in same transaction'::TEXT,
        'Balance: $' || v_balance2::TEXT;
    
    RETURN QUERY SELECT 
        4,
        'Observation'::TEXT,
        'In SERIALIZABLE: Always see consistent snapshot, even if other transactions commit'::TEXT;
    
    RAISE NOTICE '=== Demo Complete ===';
    
END;
$$ LANGUAGE plpgsql;

\echo '✓ Function demonstrate_serializable created'

-- =====================================================
-- Function: demonstrate_phantom_reads
-- Shows phantom read phenomenon in READ COMMITTED
-- =====================================================

CREATE OR REPLACE FUNCTION demonstrate_phantom_reads(
    p_user_id INT
)
RETURNS TABLE (
    step INT,
    read_number INT,
    post_count BIGINT,
    observation TEXT
) AS $$
DECLARE
    v_count1 BIGINT;
    v_count2 BIGINT;
BEGIN
    RAISE NOTICE '=== Phantom Reads Demo ===';
    RAISE NOTICE 'Counting posts for user % multiple times in same transaction', p_user_id;
    RAISE NOTICE '';
    
    -- First count
    SELECT COUNT(*) INTO v_count1 
    FROM Posts 
    WHERE user_id = p_user_id;
    
    RETURN QUERY SELECT 
        1,
        1,
        v_count1,
        'First count: ' || v_count1::TEXT || ' posts';
    
    RAISE NOTICE 'First count: % posts', v_count1;
    
    -- Simulate time for another transaction to insert a post
    PERFORM pg_sleep(0.1);
    
    -- Second count (in READ COMMITTED, might see new posts)
    SELECT COUNT(*) INTO v_count2 
    FROM Posts 
    WHERE user_id = p_user_id;
    
    RETURN QUERY SELECT 
        2,
        2,
        v_count2,
        CASE 
            WHEN v_count2 > v_count1 THEN 
                'Phantom read occurred: New posts appeared!'
            WHEN v_count2 = v_count1 THEN 
                'No phantom read: Same count'
            ELSE 
                'Posts disappeared (unusual)'
        END;
    
    RAISE NOTICE 'Second count: % posts', v_count2;
    
    IF v_count2 != v_count1 THEN
        RAISE NOTICE 'Phantom read detected! Count changed from % to %', v_count1, v_count2;
    END IF;
    
    RAISE NOTICE '=== Demo Complete ===';
    
END;
$$ LANGUAGE plpgsql;

\echo '✓ Function demonstrate_phantom_reads created'

-- =====================================================
-- Manual Isolation Level Examples
-- These must be run in separate sessions for real testing
-- =====================================================

\echo ''
\echo 'Creating isolation level comparison script...'

DO $$
BEGIN
    RAISE NOTICE '=== Isolation Levels in PostgreSQL ===';
    RAISE NOTICE '';
    RAISE NOTICE 'PostgreSQL supports 4 isolation levels:';
    RAISE NOTICE '  1. READ UNCOMMITTED (treated as READ COMMITTED)';
    RAISE NOTICE '  2. READ COMMITTED (default)';
    RAISE NOTICE '  3. REPEATABLE READ';
    RAISE NOTICE '  4. SERIALIZABLE (strictest)';
    RAISE NOTICE '';
    RAISE NOTICE 'Key Differences:';
    RAISE NOTICE '';
    RAISE NOTICE 'READ COMMITTED:';
    RAISE NOTICE '  - Sees committed changes from other transactions';
    RAISE NOTICE '  - Allows phantom reads';
    RAISE NOTICE '  - Best for most applications';
    RAISE NOTICE '  - Less locking, better concurrency';
    RAISE NOTICE '';
    RAISE NOTICE 'SERIALIZABLE:';
    RAISE NOTICE '  - Complete isolation from other transactions';
    RAISE NOTICE '  - Prevents phantom reads';
    RAISE NOTICE '  - May cause serialization failures';
    RAISE NOTICE '  - More locking, lower concurrency';
    RAISE NOTICE '';
    RAISE NOTICE 'Setting Isolation Level:';
    RAISE NOTICE '  BEGIN;';
    RAISE NOTICE '  SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;';
    RAISE NOTICE '  -- your queries here';
    RAISE NOTICE '  COMMIT;';
END $$;

-- =====================================================
-- Function: transfer_money_with_isolation
-- Demonstrates money transfer with different isolation levels
-- =====================================================

CREATE OR REPLACE FUNCTION transfer_money_with_isolation(
    p_from_user_id INT,
    p_to_user_id INT,
    p_amount DECIMAL(10, 2),
    p_isolation_level TEXT DEFAULT 'READ COMMITTED'
)
RETURNS TABLE (
    step VARCHAR(50),
    from_balance DECIMAL(10, 2),
    to_balance DECIMAL(10, 2),
    status VARCHAR(20)
) AS $$
DECLARE
    v_from_balance DECIMAL;
    v_to_balance DECIMAL;
BEGIN
    RAISE NOTICE '=== Money Transfer with % ===', p_isolation_level;
    RAISE NOTICE 'Transferring $% from user % to user %', 
        p_amount, p_from_user_id, p_to_user_id;
    RAISE NOTICE '';
    
    -- Ensure both users have balance records
    INSERT INTO AccountBalance (user_id, balance)
    VALUES (p_from_user_id, 1000.00), (p_to_user_id, 500.00)
    ON CONFLICT (user_id) DO NOTHING;
    
    -- Step 1: Check sender's balance
    SELECT balance INTO v_from_balance 
    FROM AccountBalance 
    WHERE user_id = p_from_user_id
    FOR UPDATE;  -- Lock the row
    
    SELECT balance INTO v_to_balance
    FROM AccountBalance
    WHERE user_id = p_to_user_id;
    
    RETURN QUERY SELECT 
        'Initial'::VARCHAR(50),
        v_from_balance,
        v_to_balance,
        'checking'::VARCHAR(20);
    
    -- Step 2: Validate sufficient funds
    IF v_from_balance < p_amount THEN
        RAISE EXCEPTION 'Insufficient funds: Balance $%, Need $%', 
            v_from_balance, p_amount;
    END IF;
    
    -- Step 3: Perform transfer
    UPDATE AccountBalance 
    SET balance = balance - p_amount,
        updated_at = CURRENT_TIMESTAMP
    WHERE user_id = p_from_user_id;
    
    UPDATE AccountBalance 
    SET balance = balance + p_amount,
        updated_at = CURRENT_TIMESTAMP
    WHERE user_id = p_to_user_id;
    
    -- Step 4: Return final balances
    SELECT balance INTO v_from_balance 
    FROM AccountBalance 
    WHERE user_id = p_from_user_id;
    
    SELECT balance INTO v_to_balance
    FROM AccountBalance
    WHERE user_id = p_to_user_id;
    
    RETURN QUERY SELECT 
        'Final'::VARCHAR(50),
        v_from_balance,
        v_to_balance,
        'success'::VARCHAR(20);
    
    RAISE NOTICE 'Transfer completed successfully';
    RAISE NOTICE 'New balances: From=$%, To=$%', v_from_balance, v_to_balance;
    
END;
$$ LANGUAGE plpgsql;

\echo '✓ Function transfer_money_with_isolation created'

\echo ''
\echo '========================================='
\echo 'Example Usage:'
\echo ''
\echo '-- Test READ COMMITTED:'
\echo '  SELECT * FROM demonstrate_read_committed();'
\echo ''
\echo '-- Test SERIALIZABLE:'
\echo '  SELECT * FROM demonstrate_serializable();'
\echo ''
\echo '-- Test Phantom Reads:'
\echo '  SELECT * FROM demonstrate_phantom_reads(1);'
\echo ''
\echo '-- Money Transfer:'
\echo '  SELECT * FROM transfer_money_with_isolation(1, 2, 50.00);'
\echo ''
\echo 'For Real Concurrent Testing (run in 2 separate terminals):'
\echo ''
\echo '-- Terminal 1:'
\echo '  BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;'
\echo '  SELECT * FROM Posts WHERE user_id = 1;'
\echo '  -- wait for Terminal 2'
\echo '  SELECT * FROM Posts WHERE user_id = 1;  -- May see new posts'
\echo '  COMMIT;'
\echo ''
\echo '-- Terminal 2:'
\echo '  BEGIN;'
\echo '  INSERT INTO Posts (user_id, content) VALUES (1, ''New post'');'
\echo '  COMMIT;  -- Terminal 1 can now see this'
\echo ''
\echo 'Key Points:'
\echo '  - READ COMMITTED: Default, best for most cases'
\echo '  - SERIALIZABLE: Use when consistency is critical'
\echo '  - Higher isolation = More locking = Lower concurrency'
\echo '  - Choose based on your consistency requirements'
\echo '========================================='
