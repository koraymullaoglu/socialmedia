from tests.base_test import BaseTest
from sqlalchemy import text
from api.extensions import db

class TestDatabaseViews(BaseTest):
    def setUp(self):
        super().setUp()
        self.conn = db.session.connection()
        self._seed_data()

    def _seed_data(self):
        """Seed complex data for view testing"""
        # Users
        self.conn.execute(text("""
            INSERT INTO Users (user_id, username, email, password_hash, created_at) VALUES 
            (101, 'active_user', 'au@t.com', 'h', NOW()),
            (102, 'passive_user', 'pu@t.com', 'h', NOW()),
            (103, 'popular_creator', 'pc@t.com', 'h', NOW())
        """))
        
        # Follows (102 follows 103)
        self.conn.execute(text("""
            INSERT INTO FollowStatus (status_id, status_name) VALUES (1, 'pending'), (2, 'accepted'), (3, 'rejected') ON CONFLICT DO NOTHING
        """)) 
        
        accepted_id = self.conn.execute(text("SELECT status_id FROM FollowStatus WHERE status_name = 'accepted'")).scalar()
        
        self.conn.execute(text("""
            INSERT INTO Follows (follower_id, following_id, status_id) 
            VALUES (102, 103, :sid)
        """), {"sid": accepted_id})
        
        # Posts
        self.conn.execute(text("""
            INSERT INTO Posts (post_id, user_id, content, created_at) VALUES
            (201, 103, 'Popular Content', NOW()),
            (202, 101, 'Normal Content', NOW() - INTERVAL '1 day')
        """))
        
        # Likes (Active User likes Popular Content)
        self.conn.execute(text("""
            INSERT INTO PostLikes (post_id, user_id) VALUES (201, 101)
        """))
        
        # Communities
        self.conn.execute(text("""
            INSERT INTO Communities (community_id, name, creator_id) VALUES (301, 'Test Comm', 101)
        """))
        
        self.conn.commit()

    def test_user_feed_view(self):
        """Test user_feed_view returns followed posts"""
        # User 102 follows 103, so should see post 201
        result = self.conn.execute(text("""
            SELECT * FROM user_feed_view WHERE viewing_user_id = 102
        """)).fetchall()
        
        assert len(result) == 1
        assert result[0].post_id == 201
        assert result[0].author_username == 'popular_creator'

    def test_popular_posts_view(self):
        """Test popular_posts_view ordering"""
        # Post 201 has 1 like, Post 202 has 0
        result = self.conn.execute(text("""
            SELECT * FROM popular_posts_view LIMIT 2
        """)).fetchall()
        
        assert len(result) >= 2
        # First one should be 201 because of engagement
        self.assertEqual(result[0].post_id, 201)
        self.assertGreater(result[0].engagement_score, 0)

    def test_active_users_view(self):
        """Test active_users_view aggregation"""
        # Active user (101) made a post and a like.
        result = self.conn.execute(text("""
            SELECT * FROM active_users_view WHERE user_id = 101
        """)).fetchone()
        
        assert result is not None
        assert result.total_activity >= 2 # 1 post + 1 like

    def test_community_statistics_view(self):
        """Test community_statistics_view"""
        result = self.conn.execute(text("""
            SELECT * FROM community_statistics_view WHERE community_id = 301
        """)).fetchone()
        
        assert result is not None
        assert result.community_name == 'Test Comm'
        assert result.creator_username == 'active_user'
