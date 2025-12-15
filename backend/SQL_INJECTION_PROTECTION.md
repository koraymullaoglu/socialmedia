# SQL Injection Protection Documentation

## Overview
This document explains the SQL injection protection measures implemented in the social media application and provides guidelines for maintaining security.

## Current Security Status ✅

All repository methods in this application use **parameterized queries** with SQLAlchemy's `text()` function and proper parameter binding, making them resistant to SQL injection attacks.

## How Protection Works

### 1. Parameterized Queries
All SQL queries use the `:parameter` syntax instead of string concatenation:

```python
# ✅ SECURE - Parameterized query
query = text("SELECT * FROM Users WHERE username = :username")
result = db.session.execute(query, {"username": user_input})

# ❌ INSECURE - String concatenation (NOT used in this codebase)
query = f"SELECT * FROM Users WHERE username = '{user_input}'"
result = db.session.execute(query)
```

### 2. Parameter Binding
Parameters are passed separately to `execute()` as a dictionary, ensuring they're properly escaped:

```python
# ✅ SECURE
result = self.db.session.execute(query, {
    "user_id": user_id,
    "username": username,
    "email": email
})
```

## Protected Operations

### User Repository
- ✅ `get_by_username()` - Uses `:username` parameter
- ✅ `get_by_email()` - Uses `:email` parameter
- ✅ `search()` - Uses `:search` parameter with ILIKE
- ✅ `create()` - All fields parameterized
- ✅ `update()` - All fields parameterized
- ✅ `exists_by_email()` - Uses `:email` parameter
- ✅ `exists_by_username()` - Uses `:username` parameter

### Post Repository
- ✅ `create()` - All fields parameterized
- ✅ `get_by_id()` - Uses `:post_id` parameter
- ✅ `get_by_user_id()` - Uses `:user_id` parameter
- ✅ `search_posts()` - Uses `:search` parameter with ILIKE
- ✅ `like_post()` - Uses `:post_id` and `:user_id` parameters
- ✅ All statistics queries - Properly parameterized

### Comment Repository
- ✅ `create()` - All fields parameterized
- ✅ `get_by_post_id()` - Uses `:post_id` parameter
- ✅ `get_replies()` - Uses `:comment_id` parameter
- ✅ All queries properly parameterized

### Community Repository
- ✅ `create()` - Uses stored procedure with parameters
- ✅ `search()` - Uses `:search_term` parameter with ILIKE
- ✅ `get_members()` - Uses `:community_id` parameter
- ✅ All queries properly parameterized

### Message Repository
- ✅ `create()` - All fields parameterized
- ✅ `get_conversation()` - Uses `:user1_id` and `:user2_id` parameters
- ✅ `mark_as_read()` - Uses `:message_id` parameter
- ✅ All queries properly parameterized

### Follow Repository
- ✅ `create()` - All fields parameterized
- ✅ `get_by_ids()` - Uses `:follower_id` and `:following_id` parameters
- ✅ `get_followers()` - Uses `:user_id` parameter
- ✅ All queries properly parameterized

## Special Cases: LIKE Pattern Construction

In some search methods, Python string interpolation is used to construct LIKE patterns:

```python
search_pattern = f"%{query_str}%"
result = self.db.session.execute(query, {"search": search_pattern, "limit": limit})
```

**This is still SECURE** because:
1. The pattern is constructed in Python, not in SQL
2. The constructed string is passed as a parameter to `execute()`
3. SQLAlchemy properly escapes the parameter value
4. The SQL query structure cannot be modified by user input

### Why This Works
```python
# User input: "admin' OR '1'='1"
search_pattern = f"%{query_str}%"  # Results in: "%admin' OR '1'='1%"
# This is passed as a parameter, so it searches for the literal string
# "%admin' OR '1'='1%" and doesn't execute as SQL
```

## Testing

We have comprehensive SQL injection tests in [test_sql_injection.py](tests/test_sql_injection.py) that verify:

1. **Classic SQL injection attempts** (e.g., `admin'--`, `' OR '1'='1`)
2. **Table dropping attempts** (e.g., `'; DROP TABLE Users;--`)
3. **UNION injection** (e.g., `' UNION SELECT * FROM Users--`)
4. **Special characters** (quotes, backslashes, null bytes)
5. **Unicode characters** (emoji, international characters)
6. **Parameter handling** (LIMIT, OFFSET, user IDs)

All 18 tests pass, confirming the application is protected.

## Best Practices for Developers

### ✅ DO:
1. **Always use parameterized queries**
   ```python
   query = text("SELECT * FROM Users WHERE user_id = :user_id")
   result = db.session.execute(query, {"user_id": user_id})
   ```

2. **Use the `:parameter` syntax for all values**
   ```python
   query = text("""
       INSERT INTO Posts (user_id, content, media_url)
       VALUES (:user_id, :content, :media_url)
   """)
   ```

3. **Pass parameters as a dictionary to execute()**
   ```python
   db.session.execute(query, {
       "user_id": user_id,
       "content": content,
       "media_url": media_url
   })
   ```

4. **Construct LIKE patterns in Python, then pass as parameters**
   ```python
   search_pattern = f"%{user_input}%"
   query = text("SELECT * FROM Users WHERE username ILIKE :pattern")
   db.session.execute(query, {"pattern": search_pattern})
   ```

### ❌ DON'T:
1. **Never use string concatenation or f-strings in SQL**
   ```python
   # ❌ NEVER DO THIS
   query = f"SELECT * FROM Users WHERE username = '{username}'"
   ```

2. **Never use string formatting in SQL**
   ```python
   # ❌ NEVER DO THIS
   query = "SELECT * FROM Users WHERE username = '{}'".format(username)
   ```

3. **Never use % formatting in SQL**
   ```python
   # ❌ NEVER DO THIS
   query = "SELECT * FROM Users WHERE username = '%s'" % username
   ```

4. **Never build WHERE clauses dynamically with user input**
   ```python
   # ❌ NEVER DO THIS
   where_clause = user_input  # Could be "1=1 OR username='admin'"
   query = f"SELECT * FROM Users WHERE {where_clause}"
   ```

## Additional Security Measures

### 1. Input Validation
While parameterized queries protect against SQL injection, you should still validate input:
- Check data types (integers should be integers)
- Validate email formats
- Enforce length limits
- Sanitize for business logic

### 2. Least Privilege
- Database user should have minimal necessary permissions
- Don't grant DROP, TRUNCATE, or ALTER permissions if not needed
- Use separate users for different access levels

### 3. Error Handling
- Don't expose raw SQL errors to users
- Log detailed errors internally
- Return generic error messages to clients

### 4. Regular Audits
- Review new code for proper parameterization
- Run SQL injection tests regularly
- Keep SQLAlchemy and dependencies updated

## Common SQL Injection Patterns Tested

Our test suite includes protection against:

1. **Comment-based injection**: `admin'--`, `admin'#`
2. **Tautology-based injection**: `' OR '1'='1`, `' OR 1=1--`
3. **Union-based injection**: `' UNION SELECT * FROM Users--`
4. **Stacked queries**: `'; DROP TABLE Users;--`
5. **Boolean-based blind**: `' AND 1=1--`, `' AND 1=2--`
6. **Time-based blind**: `' AND SLEEP(5)--`
7. **Special characters**: Single quotes, double quotes, backslashes
8. **Null bytes**: `\x00` injection attempts
9. **Unicode**: International characters and emoji

## Verification

To verify SQL injection protection:

```bash
# Run SQL injection tests
cd backend
python -m pytest tests/test_sql_injection.py -v

# Run all tests (includes SQL injection tests)
python run_all_tests.py
```

## Resources

- [OWASP SQL Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)
- [SQLAlchemy SQL Expression Language Tutorial](https://docs.sqlalchemy.org/en/14/core/tutorial.html)
- [PostgreSQL Security Best Practices](https://www.postgresql.org/docs/current/sql-syntax.html)

## Summary

✅ **All repository methods are protected against SQL injection**  
✅ **Comprehensive test coverage with 18 security tests**  
✅ **Parameterized queries used throughout**  
✅ **No raw string concatenation in SQL**  
✅ **Best practices documented for future development**

The application follows industry-standard security practices and has been thoroughly tested against common SQL injection attack vectors.
