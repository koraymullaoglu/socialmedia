-- Trigger functions for cascade cleanup operations
-- Handle cleanup of likes and comments when posts are deleted

-- Function to cleanup post likes when a post is deleted
CREATE OR REPLACE FUNCTION cleanup_post_likes()
RETURNS TRIGGER AS $$
BEGIN
    -- Delete all likes associated with the post
    DELETE FROM PostLikes WHERE post_id = OLD.post_id;
    
    -- Log the cleanup operation
    RAISE NOTICE 'Cleaned up likes for post_id: %', OLD.post_id;
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Function to cleanup post comments when a post is deleted
CREATE OR REPLACE FUNCTION cleanup_post_comments()
RETURNS TRIGGER AS $$
BEGIN
    -- Delete all comments associated with the post
    DELETE FROM Comments WHERE post_id = OLD.post_id;
    
    -- Log the cleanup operation
    RAISE NOTICE 'Cleaned up comments for post_id: %', OLD.post_id;
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Trigger to cleanup likes before post deletion
CREATE TRIGGER cleanup_likes_on_post_delete
    BEFORE DELETE ON Posts
    FOR EACH ROW
    EXECUTE FUNCTION cleanup_post_likes();

-- Trigger to cleanup comments before post deletion
CREATE TRIGGER cleanup_comments_on_post_delete
    BEFORE DELETE ON Posts
    FOR EACH ROW
    EXECUTE FUNCTION cleanup_post_comments();

-- Optional: Function to update post stats in a denormalized column (if you add one)
-- This is useful if you want to cache like/comment counts in the Posts table
-- CREATE OR REPLACE FUNCTION update_post_stats()
-- RETURNS TRIGGER AS $$
-- BEGIN
--     IF (TG_OP = 'INSERT') THEN
--         IF (TG_TABLE_NAME = 'PostLikes') THEN
--             UPDATE Posts SET like_count = like_count + 1 WHERE post_id = NEW.post_id;
--         ELSIF (TG_TABLE_NAME = 'Comments') THEN
--             UPDATE Posts SET comment_count = comment_count + 1 WHERE post_id = NEW.post_id;
--         END IF;
--         RETURN NEW;
--     ELSIF (TG_OP = 'DELETE') THEN
--         IF (TG_TABLE_NAME = 'PostLikes') THEN
--             UPDATE Posts SET like_count = like_count - 1 WHERE post_id = OLD.post_id;
--         ELSIF (TG_TABLE_NAME = 'Comments') THEN
--             UPDATE Posts SET comment_count = comment_count - 1 WHERE post_id = OLD.post_id;
--         END IF;
--         RETURN OLD;
--     END IF;
-- END;
-- $$ LANGUAGE plpgsql;
