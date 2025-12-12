-- Trigger functions for audit logging
-- Track user deletions with full user data for compliance and recovery

-- Function to log user deletions
CREATE OR REPLACE FUNCTION log_user_deletion()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert audit log entry with OLD record data
    INSERT INTO AuditLog (
        table_name,
        operation,
        user_id,
        username,
        email,
        record_data,
        deleted_at
    ) VALUES (
        'Users',
        'DELETE',
        OLD.user_id,
        OLD.username,
        OLD.email,
        jsonb_build_object(
            'user_id', OLD.user_id,
            'username', OLD.username,
            'email', OLD.email,
            'bio', OLD.bio,
            'profile_picture_url', OLD.profile_picture_url,
            'is_private', OLD.is_private,
            'created_at', OLD.created_at,
            'updated_at', OLD.updated_at
        ),
        CURRENT_TIMESTAMP
    );
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Trigger for user deletions
CREATE TRIGGER audit_user_deletion
    BEFORE DELETE ON Users
    FOR EACH ROW
    EXECUTE FUNCTION log_user_deletion();

-- Optional: Function to log post deletions (for comprehensive auditing)
CREATE OR REPLACE FUNCTION log_post_deletion()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO AuditLog (
        table_name,
        operation,
        user_id,
        record_data,
        deleted_at
    ) VALUES (
        'Posts',
        'DELETE',
        OLD.user_id,
        jsonb_build_object(
            'post_id', OLD.post_id,
            'user_id', OLD.user_id,
            'community_id', OLD.community_id,
            'content', OLD.content,
            'media_url', OLD.media_url,
            'created_at', OLD.created_at,
            'updated_at', OLD.updated_at
        ),
        CURRENT_TIMESTAMP
    );
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Trigger for post deletions (optional, uncomment if needed)
-- CREATE TRIGGER audit_post_deletion
--     BEFORE DELETE ON Posts
--     FOR EACH ROW
--     EXECUTE FUNCTION log_post_deletion();
