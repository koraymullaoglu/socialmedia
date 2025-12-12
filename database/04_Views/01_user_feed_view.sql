-- User Feed View
-- Shows posts from users that a given user follows
-- This view makes it easy to get a user's personalized feed

CREATE OR REPLACE VIEW user_feed_view AS
SELECT 
    p.post_id,
    p.user_id,
    u.username,
    u.profile_picture_url,
    p.content,
    p.media_url,
    p.community_id,
    c.name AS community_name,
    p.created_at,
    p.updated_at,
    -- Engagement metrics
    COALESCE(like_counts.like_count, 0) AS like_count,
    COALESCE(comment_counts.comment_count, 0) AS comment_count,
    -- Following information
    f.follower_id AS viewing_user_id
FROM Follows f
JOIN Posts p ON f.following_id = p.user_id
JOIN Users u ON p.user_id = u.user_id
LEFT JOIN Communities c ON p.community_id = c.community_id
LEFT JOIN (
    SELECT post_id, COUNT(*) AS like_count
    FROM PostLikes
    GROUP BY post_id
) like_counts ON p.post_id = like_counts.post_id
LEFT JOIN (
    SELECT post_id, COUNT(*) AS comment_count
    FROM Comments
    GROUP BY post_id
) comment_counts ON p.post_id = comment_counts.post_id
WHERE f.status_id = (SELECT status_id FROM FollowStatus WHERE status_name = 'accepted')
ORDER BY p.created_at DESC;

-- Example usage:
-- Get feed for user with user_id = 1
-- SELECT * FROM user_feed_view WHERE viewing_user_id = 1 LIMIT 20;

-- Create index on Follows table for better performance
CREATE INDEX IF NOT EXISTS idx_follows_follower_status ON Follows(follower_id, status_id);
CREATE INDEX IF NOT EXISTS idx_follows_following_status ON Follows(following_id, status_id);
