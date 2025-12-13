# CHECK Constraints Documentation

## Overview

This document describes the CHECK constraints added to the database for data integrity validation.

---

## Constraints Summary

| Table | Constraint | Purpose | Rule |
|-------|-----------|---------|------|
| Posts | `chk_posts_content_or_media` | Ensure post has content | `content OR media_url` must be present |
| Users | `chk_users_email_format` | Validate email format | Must match email regex pattern |
| Comments | `chk_comments_min_length` | Prevent empty comments | Minimum 1 non-whitespace character |
| Messages | `chk_messages_different_users` | Prevent self-messaging | `sender_id != receiver_id` |

---

## 1. Posts: Content OR Media URL

### Constraint Name
`chk_posts_content_or_media`

### Rule
At least one of `content` or `media_url` must be present and non-empty.

### SQL
```sql
ALTER TABLE Posts
ADD CONSTRAINT chk_posts_content_or_media
CHECK (
    (content IS NOT NULL AND content != '') 
    OR 
    (media_url IS NOT NULL AND media_url != '')
);
```

### Valid Examples
```sql
-- Text-only post
INSERT INTO Posts (user_id, content) 
VALUES (1, 'Hello world!');

-- Image-only post
INSERT INTO Posts (user_id, media_url) 
VALUES (1, 'https://example.com/image.jpg');

-- Post with both
INSERT INTO Posts (user_id, content, media_url) 
VALUES (1, 'Check this out!', 'https://example.com/photo.jpg');
```

### Invalid Examples
```sql
-- ✗ FAIL: Neither content nor media
INSERT INTO Posts (user_id) VALUES (1);

-- ✗ FAIL: Empty content, no media
INSERT INTO Posts (user_id, content) VALUES (1, '');

-- ✗ FAIL: NULL content, NULL media
INSERT INTO Posts (user_id, content, media_url) VALUES (1, NULL, NULL);
```

### Error Message
```
ERROR:  new row for relation "posts" violates check constraint "chk_posts_content_or_media"
DETAIL:  Failing row contains (id, user_id, null, null, ...).
```

---

## 2. Users: Email Format Validation

### Constraint Name
`chk_users_email_format`

### Rule
Email must match a valid email format: `local-part@domain.tld`

### SQL
```sql
ALTER TABLE Users
ADD CONSTRAINT chk_users_email_format
CHECK (
    email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
);
```

### Regex Pattern Breakdown
```
^                       Start of string
[A-Za-z0-9._%+-]+      Local part (letters, numbers, . _ % + -)
@                       At symbol (required)
[A-Za-z0-9.-]+         Domain name (letters, numbers, . -)
\.                      Dot before TLD
[A-Za-z]{2,}           Top-level domain (2+ letters)
$                       End of string
```

### Valid Examples
```sql
-- Standard email
INSERT INTO Users (username, email, password_hash) 
VALUES ('user1', 'john@example.com', 'hash');

-- Email with subdomain
INSERT INTO Users (username, email, password_hash) 
VALUES ('user2', 'jane@mail.example.com', 'hash');

-- Complex email
INSERT INTO Users (username, email, password_hash) 
VALUES ('user3', 'user.name+tag@example.co.uk', 'hash');

-- Email with numbers
INSERT INTO Users (username, email, password_hash) 
VALUES ('user4', 'user123@domain123.org', 'hash');
```

### Invalid Examples
```sql
-- ✗ FAIL: No @ symbol
INSERT INTO Users (username, email, password_hash) 
VALUES ('user5', 'userexample.com', 'hash');

-- ✗ FAIL: No domain
INSERT INTO Users (username, email, password_hash) 
VALUES ('user6', 'user@', 'hash');

-- ✗ FAIL: No TLD
INSERT INTO Users (username, email, password_hash) 
VALUES ('user7', 'user@example', 'hash');

-- ✗ FAIL: Spaces in email
INSERT INTO Users (username, email, password_hash) 
VALUES ('user8', 'user name@example.com', 'hash');

-- ✗ FAIL: Missing local part
INSERT INTO Users (username, email, password_hash) 
VALUES ('user9', '@example.com', 'hash');

-- ✗ FAIL: TLD too short
INSERT INTO Users (username, email, password_hash) 
VALUES ('user10', 'user@example.c', 'hash');
```

### Error Message
```
ERROR:  new row for relation "users" violates check constraint "chk_users_email_format"
DETAIL:  Failing row contains (id, username, "invalid@email", ...).
```

---

## 3. Comments: Minimum Length

### Constraint Name
`chk_comments_min_length`

### Rule
Content must have at least 1 non-whitespace character after trimming.

### SQL
```sql
ALTER TABLE Comments
ADD CONSTRAINT chk_comments_min_length
CHECK (
    LENGTH(TRIM(content)) >= 1
);
```

### Valid Examples
```sql
-- Single character
INSERT INTO Comments (post_id, user_id, content) 
VALUES (1, 1, '!');

-- Normal comment
INSERT INTO Comments (post_id, user_id, content) 
VALUES (1, 1, 'Great post!');

-- With spaces around (trimmed)
INSERT INTO Comments (post_id, user_id, content) 
VALUES (1, 1, '  Nice!  ');

-- Emoji
INSERT INTO Comments (post_id, user_id, content) 
VALUES (1, 1, '👍');
```

### Invalid Examples
```sql
-- ✗ FAIL: Empty string
INSERT INTO Comments (post_id, user_id, content) 
VALUES (1, 1, '');

-- ✗ FAIL: Only spaces
INSERT INTO Comments (post_id, user_id, content) 
VALUES (1, 1, '     ');

-- ✗ FAIL: Only tabs/newlines
INSERT INTO Comments (post_id, user_id, content) 
VALUES (1, 1, E'\t\n\r');

-- ✗ FAIL: Mixed whitespace
INSERT INTO Comments (post_id, user_id, content) 
VALUES (1, 1, '  \t  \n  ');
```

### Error Message
```
ERROR:  new row for relation "comments" violates check constraint "chk_comments_min_length"
DETAIL:  Failing row contains (id, post_id, user_id, "   ", ...).
```

---

## 4. Messages: Different Users

### Constraint Name
`chk_messages_different_users`

### Rule
Sender and receiver must be different users (no self-messaging).

### SQL
```sql
ALTER TABLE Messages
ADD CONSTRAINT chk_messages_different_users
CHECK (
    sender_id != receiver_id
);
```

### Valid Examples
```sql
-- User 1 sends to User 2
INSERT INTO Messages (sender_id, receiver_id, content) 
VALUES (1, 2, 'Hello!');

-- User 2 replies to User 1
INSERT INTO Messages (sender_id, receiver_id, content) 
VALUES (2, 1, 'Hi there!');

-- User 1 sends to User 3
INSERT INTO Messages (sender_id, receiver_id, content) 
VALUES (1, 3, 'Hey!');
```

### Invalid Examples
```sql
-- ✗ FAIL: User sends message to themselves
INSERT INTO Messages (sender_id, receiver_id, content) 
VALUES (1, 1, 'Note to self');

-- ✗ FAIL: Same user ID
INSERT INTO Messages (sender_id, receiver_id, content) 
VALUES (5, 5, 'Self message');
```

### Error Message
```
ERROR:  new row for relation "messages" violates check constraint "chk_messages_different_users"
DETAIL:  Failing row contains (id, 1, 1, "Note to self", ...).
```

---

## Testing

### Run All Tests
```bash
psql -U username -d database -f test_check_constraints.sql
```

### Expected Output
```
✓ PASS: Post with only content accepted
✓ PASS: Post with only media_url accepted
✓ PASS: Empty post rejected correctly
✓ PASS: Standard email accepted
✓ PASS: Email without @ rejected correctly
✓ PASS: Single character comment accepted
✓ PASS: Empty comment rejected correctly
✓ PASS: Message to different user accepted
✓ PASS: Self-message rejected correctly

Total Tests: 24
All CHECK constraints are working correctly!
```

---

## Application Integration

### Backend Validation (Python Example)

```python
from sqlalchemy.exc import IntegrityError

# Posts validation
def create_post(user_id, content=None, media_url=None):
    if not content and not media_url:
        raise ValueError("Post must have content or media_url")
    
    try:
        post = Post(user_id=user_id, content=content, media_url=media_url)
        db.session.add(post)
        db.session.commit()
    except IntegrityError as e:
        if 'chk_posts_content_or_media' in str(e):
            raise ValueError("Post must have content or media")
        raise

# Email validation
import re

def validate_email(email):
    pattern = r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
    if not re.match(pattern, email):
        raise ValueError("Invalid email format")

# Comments validation
def create_comment(post_id, user_id, content):
    if len(content.strip()) < 1:
        raise ValueError("Comment cannot be empty")
    
    try:
        comment = Comment(post_id=post_id, user_id=user_id, content=content)
        db.session.add(comment)
        db.session.commit()
    except IntegrityError as e:
        if 'chk_comments_min_length' in str(e):
            raise ValueError("Comment must have at least 1 character")
        raise

# Messages validation
def send_message(sender_id, receiver_id, content):
    if sender_id == receiver_id:
        raise ValueError("Cannot send message to yourself")
    
    try:
        message = Message(sender_id=sender_id, receiver_id=receiver_id, content=content)
        db.session.add(message)
        db.session.commit()
    except IntegrityError as e:
        if 'chk_messages_different_users' in str(e):
            raise ValueError("Sender and receiver must be different")
        raise
```

### Frontend Validation (JavaScript Example)

```javascript
// Email validation
function validateEmail(email) {
    const pattern = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;
    return pattern.test(email);
}

// Post validation
function validatePost(content, mediaUrl) {
    return (content && content.trim() !== '') || 
           (mediaUrl && mediaUrl.trim() !== '');
}

// Comment validation
function validateComment(content) {
    return content && content.trim().length >= 1;
}

// Message validation
function validateMessage(senderId, receiverId) {
    return senderId !== receiverId;
}

// Usage in form submission
async function submitPost(content, mediaUrl) {
    if (!validatePost(content, mediaUrl)) {
        alert('Post must have content or media URL');
        return;
    }
    
    try {
        await api.createPost({ content, media_url: mediaUrl });
    } catch (error) {
        if (error.message.includes('chk_posts_content_or_media')) {
            alert('Invalid post: must have content or media');
        }
    }
}
```

---

## Maintenance

### View All CHECK Constraints

```sql
SELECT 
    tc.table_name,
    tc.constraint_name,
    cc.check_clause
FROM information_schema.table_constraints tc
JOIN information_schema.check_constraints cc 
    ON tc.constraint_name = cc.constraint_name
WHERE tc.table_schema = 'public'
  AND tc.constraint_type = 'CHECK'
ORDER BY tc.table_name;
```

### Drop a Constraint

```sql
-- If you need to remove a constraint
ALTER TABLE Posts DROP CONSTRAINT chk_posts_content_or_media;
ALTER TABLE Users DROP CONSTRAINT chk_users_email_format;
ALTER TABLE Comments DROP CONSTRAINT chk_comments_min_length;
ALTER TABLE Messages DROP CONSTRAINT chk_messages_different_users;
```

### Modify a Constraint

```sql
-- To modify, you must drop and recreate
ALTER TABLE Posts DROP CONSTRAINT chk_posts_content_or_media;
ALTER TABLE Posts ADD CONSTRAINT chk_posts_content_or_media
CHECK (content IS NOT NULL OR media_url IS NOT NULL);
```

---

## Best Practices

1. **Database + Application Validation**
   - Always validate in both database (constraints) and application (user feedback)
   - Database constraints are the last line of defense

2. **Clear Error Messages**
   - Catch constraint violations and provide user-friendly messages
   - Don't expose raw database errors to end users

3. **Test Edge Cases**
   - Empty strings, whitespace, null values
   - Special characters, unicode
   - Boundary conditions

4. **Performance Considerations**
   - CHECK constraints are evaluated on every INSERT/UPDATE
   - Regex patterns (email) have minimal performance impact
   - Keep constraints simple and efficient

5. **Documentation**
   - Document all constraints in code comments
   - Include examples in API documentation
   - Keep this guide updated

---

## Troubleshooting

### Issue: Existing data violates constraint

**Problem:** Cannot add constraint because existing data violates it.

**Solution:**
```sql
-- Check for violating rows first
SELECT * FROM Posts WHERE content IS NULL AND media_url IS NULL;

-- Fix data before adding constraint
UPDATE Posts SET content = 'No content' 
WHERE content IS NULL AND media_url IS NULL;

-- Then add constraint
ALTER TABLE Posts ADD CONSTRAINT chk_posts_content_or_media ...;
```

### Issue: Constraint too restrictive

**Problem:** Valid data is being rejected.

**Solution:** Review and relax the constraint:
```sql
-- Example: Allow shorter comments
ALTER TABLE Comments DROP CONSTRAINT chk_comments_min_length;
ALTER TABLE Comments ADD CONSTRAINT chk_comments_min_length
CHECK (LENGTH(TRIM(content)) >= 0);  -- Allow empty after trim
```

### Issue: Need to bypass constraint temporarily

**Problem:** Need to import legacy data that violates constraints.

**Solution:**
```sql
-- Temporarily disable constraint (PostgreSQL 12+)
ALTER TABLE Posts ALTER CONSTRAINT chk_posts_content_or_media NOT VALID;

-- Import data
COPY Posts FROM 'legacy_data.csv';

-- Re-enable and validate
ALTER TABLE Posts VALIDATE CONSTRAINT chk_posts_content_or_media;
```

---

## Related Documentation

- [PostgreSQL CHECK Constraints](https://www.postgresql.org/docs/current/ddl-constraints.html#DDL-CONSTRAINTS-CHECK-CONSTRAINTS)
- [Pattern Matching](https://www.postgresql.org/docs/current/functions-matching.html)
- Migration: `03_add_check_constraints.sql`
- Tests: `test_check_constraints.sql`
