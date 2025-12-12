-- Community Statistics View
-- Shows comprehensive statistics for each community
-- Includes member counts, post counts, and activity metrics

CREATE OR REPLACE VIEW community_statistics_view AS
SELECT 
    c.community_id,
    c.name AS community_name,
    c.description,
    c.creator_id,
    creator.username AS creator_username,
    c.created_at,
    -- Member statistics
    COALESCE(member_counts.total_members, 0) AS total_members,
    COALESCE(member_counts.admin_count, 0) AS admin_count,
    COALESCE(member_counts.moderator_count, 0) AS moderator_count,
    COALESCE(member_counts.member_count, 0) AS regular_member_count,
    -- Content statistics
    COALESCE(post_counts.total_posts, 0) AS total_posts,
    COALESCE(post_counts.posts_last_7_days, 0) AS posts_last_7_days,
    COALESCE(post_counts.posts_last_30_days, 0) AS posts_last_30_days,
    -- Engagement statistics
    COALESCE(engagement.total_likes, 0) AS total_likes,
    COALESCE(engagement.total_comments, 0) AS total_comments,
    COALESCE(engagement.avg_likes_per_post, 0) AS avg_likes_per_post,
    COALESCE(engagement.avg_comments_per_post, 0) AS avg_comments_per_post,
    -- Activity metrics
    CASE 
        WHEN post_counts.posts_last_7_days > 0 THEN 'active'
        WHEN post_counts.posts_last_30_days > 0 THEN 'moderate'
        ELSE 'inactive'
    END AS activity_level,
    -- Last activity
    post_counts.last_post_at
FROM Communities c
JOIN Users creator ON c.creator_id = creator.user_id
LEFT JOIN (
    SELECT 
        cm.community_id,
        COUNT(*) AS total_members,
        COUNT(*) FILTER (WHERE r.role_name = 'admin') AS admin_count,
        COUNT(*) FILTER (WHERE r.role_name = 'moderator') AS moderator_count,
        COUNT(*) FILTER (WHERE r.role_name = 'member') AS member_count
    FROM CommunityMembers cm
    LEFT JOIN Roles r ON cm.role_id = r.role_id
    GROUP BY cm.community_id
) member_counts ON c.community_id = member_counts.community_id
LEFT JOIN (
    SELECT 
        community_id,
        COUNT(*) AS total_posts,
        COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '7 days') AS posts_last_7_days,
        COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '30 days') AS posts_last_30_days,
        MAX(created_at) AS last_post_at
    FROM Posts
    GROUP BY community_id
) post_counts ON c.community_id = post_counts.community_id
LEFT JOIN (
    SELECT 
        p.community_id,
        COUNT(pl.*) AS total_likes,
        COUNT(DISTINCT co.comment_id) AS total_comments,
        ROUND(AVG(like_counts.like_count), 2) AS avg_likes_per_post,
        ROUND(AVG(comment_counts.comment_count), 2) AS avg_comments_per_post
    FROM Posts p
    LEFT JOIN PostLikes pl ON p.post_id = pl.post_id
    LEFT JOIN Comments co ON p.post_id = co.post_id
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
    WHERE p.community_id IS NOT NULL
    GROUP BY p.community_id
) engagement ON c.community_id = engagement.community_id
ORDER BY total_members DESC, total_posts DESC;

-- Example usage:
-- Get all community statistics
-- SELECT * FROM community_statistics_view;

-- Get top 10 communities by member count
-- SELECT * FROM community_statistics_view ORDER BY total_members DESC LIMIT 10;

-- Get active communities (posted in last 7 days)
-- SELECT * FROM community_statistics_view WHERE activity_level = 'active';

-- Get communities with more than 100 members
-- SELECT * FROM community_statistics_view WHERE total_members > 100;
