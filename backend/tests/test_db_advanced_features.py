import unittest
from sqlalchemy import text
from api.extensions import db
from app import app

class TestDatabaseAdvancedFeatures(unittest.TestCase):
    """Test advanced database features (Transactions, Window Functions, CTEs)"""

    @classmethod
    def setUpClass(cls):
        """Set up test application context"""
        cls.app = app
        cls.app_context = cls.app.app_context()
        cls.app_context.push()

    @classmethod
    def tearDownClass(cls):
        """Remove application context"""
        cls.app_context.pop()

    def setUp(self):
        """Clean up and setup data before each test"""
        try:
            db.session.rollback()
            # Clean relevant tables
            db.session.execute(text("TRUNCATE TABLE Communities, CommunityMembers, Posts, Comments, Follows, Users RESTART IDENTITY CASCADE"))
            db.session.commit()
            
            # Create standard test users
            db.session.execute(text("""
                INSERT INTO Users (username, email, password_hash)
                VALUES 
                ('user1', 'u1@test.com', 'hash'),
                ('user2', 'u2@test.com', 'hash'),
                ('user3', 'u3@test.com', 'hash')
            """))
            db.session.commit()
            
            # Get IDs
            self.u1 = db.session.execute(text("SELECT user_id FROM Users WHERE username='user1'")).scalar()
            self.u2 = db.session.execute(text("SELECT user_id FROM Users WHERE username='user2'")).scalar()
            self.u3 = db.session.execute(text("SELECT user_id FROM Users WHERE username='user3'")).scalar()
            
        except Exception as e:
            db.session.rollback()


    def tearDown(self):
        db.session.remove()

    def test_transaction_community_creation(self):
        """Test atomic community creation procedure"""

        
        try:
            # Call stored function
            result = db.session.execute(
                text("SELECT * FROM create_community_with_admin(:uid, 'Atomic Comm', 'Desc', FALSE)"),
                {"uid": self.u1}
            ).fetchone()
            
            db.session.commit()
            
            # Verify result
            self.assertIsNotNone(result)
            self.assertEqual(result.community_name, 'Atomic Comm')
            self.assertEqual(result.status, 'success')
            
            # Verify data in tables
            comm_exists = db.session.execute(text("SELECT 1 FROM Communities WHERE name='Atomic Comm'")).scalar()
            member_exists = db.session.execute(text("SELECT 1 FROM CommunityMembers WHERE user_id=:uid AND role_id=(SELECT role_id FROM Roles WHERE role_name='admin')"), {"uid": self.u1}).scalar()
            
            self.assertTrue(comm_exists)
            self.assertTrue(member_exists)

            
        except Exception as e:
            self.fail(f"Transaction test failed: {e}")

    def test_window_function_ranking(self):
        """Test user activity ranking window function view"""

        
        # Create posts for ranking
        # User 1: 3 posts
        # User 2: 1 post
        # User 3: 0 posts
        
        for i in range(3):
            db.session.execute(text("INSERT INTO Posts (user_id, content) VALUES (:uid, 'Post')"), {"uid": self.u1})
        
        db.session.execute(text("INSERT INTO Posts (user_id, content) VALUES (:uid, 'Post')"), {"uid": self.u2})
        db.session.commit()
        
        # Query view
        results = db.session.execute(text("SELECT * FROM user_activity_ranking ORDER BY post_rank")).fetchall()
        
        # Verify Rankings
        # Rank 1: User 1 (3 posts)
        # Rank 2: User 2 (1 post)
        # Rank 3: User 3 (0 posts) or not present if inner join? View uses LEFT JOIN.
        
        u1_rank = next((r for r in results if r.username == 'user1'), None)
        u2_rank = next((r for r in results if r.username == 'user2'), None)
        
        self.assertIsNotNone(u1_rank)
        self.assertEqual(u1_rank.post_rank, 1)
        self.assertEqual(u1_rank.total_posts, 3)
        
        self.assertIsNotNone(u2_rank)
        self.assertEqual(u2_rank.post_rank, 2)


    def test_cte_comment_thread(self):
        """Test recursive CTE for comment threads"""

        
        # Setup Post
        db.session.execute(text("INSERT INTO Posts (user_id, content) VALUES (:uid, 'Root Post')"), {"uid": self.u1})
        post_id = db.session.execute(text("SELECT post_id FROM Posts WHERE user_id=:uid"), {"uid": self.u1}).scalar()
        
        # Setup Comments (Tree)
        # 1. Root Comment (User 1)
        #    2. Reply (User 2)
        #       3. Nested Reply (User 3)
        
        # Root
        db.session.execute(text("INSERT INTO Comments (post_id, user_id, content) VALUES (:pid, :uid, 'Root')"), {"pid": post_id, "uid": self.u1})
        c1 = db.session.execute(text("SELECT comment_id FROM Comments WHERE content='Root'")).scalar()
        
        # Reply
        db.session.execute(text("INSERT INTO Comments (post_id, user_id, content, parent_comment_id) VALUES (:pid, :uid, 'Reply', :par)"), {"pid": post_id, "uid": self.u2, "par": c1})
        c2 = db.session.execute(text("SELECT comment_id FROM Comments WHERE content='Reply'")).scalar()
        
        # Nested
        db.session.execute(text("INSERT INTO Comments (post_id, user_id, content, parent_comment_id) VALUES (:pid, :uid, 'Nested', :par)"), {"pid": post_id, "uid": self.u3, "par": c2})
        
        db.session.commit()
        
        # Call CTE function
        thread = db.session.execute(text("SELECT * FROM get_comment_thread(:pid)"), {"pid": post_id}).fetchall()
        
        # Verify Depth and Structure
        self.assertEqual(len(thread), 3)
        
        root = thread[0]
        reply = thread[1]
        nested = thread[2]
        
        self.assertEqual(root.depth, 0)
        self.assertEqual(reply.depth, 1)
        self.assertEqual(nested.depth, 2)
        
        self.assertEqual(reply.parent_comment_id, root.comment_id)
        self.assertEqual(nested.parent_comment_id, reply.comment_id)


if __name__ == '__main__':
    unittest.main()
