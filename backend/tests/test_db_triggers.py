"""
Test database triggers functionality
Tests updated_at triggers, audit logs, and cascade cleanup
"""
import unittest
import time
from datetime import datetime
from sqlalchemy import text
from api.extensions import db
from api.entities.entities import User, Post, Comment, PostLike
from api.repositories.user_repository import UserRepository
from api.repositories.post_repository import PostRepository
from api.repositories.comment_repository import CommentRepository


class TestDatabaseTriggers(unittest.TestCase):
    """Test cases for database triggers"""

    @classmethod
    def setUpClass(cls):
        """Set up test database connection"""
        # Import app to initialize database
        from app import app
        cls.app = app
        cls.app_context = cls.app.app_context()
        cls.app_context.push()

    @classmethod
    def tearDownClass(cls):
        """Clean up test database connection"""
        cls.app_context.pop()

    def setUp(self):
        """Set up test fixtures"""
        self.user_repo = UserRepository()
        self.post_repo = PostRepository()
        self.comment_repo = CommentRepository()

    def tearDown(self):
        """Clean up test data"""
        # Clean up test users created during tests
        try:
            db.session.rollback()  # Rollback any failed transactions first
            db.session.execute(text("DELETE FROM Users WHERE username LIKE 'trigger_test_%'"))
            db.session.commit()
        except Exception as e:

            db.session.rollback()

    def test_updated_at_trigger_for_users(self):
        """Test that updated_at is automatically set when user is updated"""

        
        # Create a test user
        query = text("""
            INSERT INTO Users (username, email, password_hash, bio)
            VALUES (:username, :email, :password_hash, :bio)
            RETURNING user_id, username, created_at, updated_at
        """)
        result = db.session.execute(query, {
            "username": "trigger_test_user1",
            "email": "trigger1@test.com",
            "password_hash": "hash123",
            "bio": "Original bio"
        })
        db.session.commit()
        
        row = result.fetchone()
        user_id = row.user_id
        original_updated_at = row.updated_at
        
        # Wait a moment to ensure timestamp difference
        time.sleep(0.1)
        
        # Update the user
        update_query = text("""
            UPDATE Users 
            SET bio = :bio 
            WHERE user_id = :user_id
            RETURNING updated_at
        """)
        result = db.session.execute(update_query, {
            "bio": "Updated bio",
            "user_id": user_id
        })
        db.session.commit()
        
        new_updated_at = result.fetchone().updated_at
        
        # Verify updated_at changed
        self.assertNotEqual(original_updated_at, new_updated_at)
        self.assertGreater(new_updated_at, original_updated_at)


    def test_updated_at_trigger_for_posts(self):
        """Test that updated_at is automatically set when post is updated"""

        
        # Create a test user first
        query = text("""
            INSERT INTO Users (username, email, password_hash)
            VALUES (:username, :email, :password_hash)
            RETURNING user_id
        """)
        result = db.session.execute(query, {
            "username": "trigger_test_user2",
            "email": "trigger2@test.com",
            "password_hash": "hash123"
        })
        db.session.commit()
        user_id = result.fetchone().user_id
        
        # Create a post
        post_query = text("""
            INSERT INTO Posts (user_id, content)
            VALUES (:user_id, :content)
            RETURNING post_id, created_at, updated_at
        """)
        result = db.session.execute(post_query, {
            "user_id": user_id,
            "content": "Original content"
        })
        db.session.commit()
        
        row = result.fetchone()
        post_id = row.post_id
        original_updated_at = row.updated_at
        
        # Wait a moment
        time.sleep(0.1)
        
        # Update the post
        update_query = text("""
            UPDATE Posts 
            SET content = :content 
            WHERE post_id = :post_id
            RETURNING updated_at
        """)
        result = db.session.execute(update_query, {
            "content": "Updated content",
            "post_id": post_id
        })
        db.session.commit()
        
        new_updated_at = result.fetchone().updated_at
        
        # Verify updated_at changed
        self.assertNotEqual(original_updated_at, new_updated_at)
        self.assertGreater(new_updated_at, original_updated_at)


    def test_audit_log_trigger_on_user_deletion(self):
        """Test that user deletion is logged in AuditLog table"""

        
        # Create a test user
        query = text("""
            INSERT INTO Users (username, email, password_hash, bio)
            VALUES (:username, :email, :password_hash, :bio)
            RETURNING user_id, username
        """)
        result = db.session.execute(query, {
            "username": "trigger_test_user3",
            "email": "trigger3@test.com",
            "password_hash": "hash123",
            "bio": "User to be deleted"
        })
        db.session.commit()
        
        row = result.fetchone()
        user_id = row.user_id
        username = row.username
        
        # Check audit log before deletion
        count_query = text("SELECT COUNT(*) FROM AuditLog WHERE user_id = :user_id")
        before_count = db.session.execute(count_query, {"user_id": user_id}).scalar()
        
        # Delete the user
        delete_query = text("DELETE FROM Users WHERE user_id = :user_id")
        db.session.execute(delete_query, {"user_id": user_id})
        db.session.commit()
        
        # Check audit log after deletion
        audit_query = text("""
            SELECT table_name, operation, username, email, record_data
            FROM AuditLog 
            WHERE user_id = :user_id
            ORDER BY deleted_at DESC
            LIMIT 1
        """)
        result = db.session.execute(audit_query, {"user_id": user_id})
        audit_row = result.fetchone()
        
        # Verify audit log entry exists
        self.assertIsNotNone(audit_row)
        self.assertEqual(audit_row.table_name, "Users")
        self.assertEqual(audit_row.operation, "DELETE")
        self.assertEqual(audit_row.username, username)


    def test_cascade_cleanup_on_post_deletion(self):
        """Test that likes and comments are cleaned up when post is deleted"""

        
        # Create a test user
        query = text("""
            INSERT INTO Users (username, email, password_hash)
            VALUES (:username, :email, :password_hash)
            RETURNING user_id
        """)
        result = db.session.execute(query, {
            "username": "trigger_test_user4",
            "email": "trigger4@test.com",
            "password_hash": "hash123"
        })
        db.session.commit()
        user_id = result.fetchone().user_id
        
        # Create a post
        post_query = text("""
            INSERT INTO Posts (user_id, content)
            VALUES (:user_id, :content)
            RETURNING post_id
        """)
        result = db.session.execute(post_query, {
            "user_id": user_id,
            "content": "Post to be deleted"
        })
        db.session.commit()
        post_id = result.fetchone().post_id
        
        # Add likes
        like_query = text("""
            INSERT INTO PostLikes (post_id, user_id)
            VALUES (:post_id, :user_id)
        """)
        db.session.execute(like_query, {"post_id": post_id, "user_id": user_id})
        db.session.commit()
        
        # Add comments
        comment_query = text("""
            INSERT INTO Comments (post_id, user_id, content)
            VALUES (:post_id, :user_id, :content)
        """)
        db.session.execute(comment_query, {
            "post_id": post_id,
            "user_id": user_id,
            "content": "Test comment"
        })
        db.session.commit()
        
        # Count likes and comments before deletion
        like_count_query = text("SELECT COUNT(*) FROM PostLikes WHERE post_id = :post_id")
        comment_count_query = text("SELECT COUNT(*) FROM Comments WHERE post_id = :post_id")
        
        likes_before = db.session.execute(like_count_query, {"post_id": post_id}).scalar()
        comments_before = db.session.execute(comment_count_query, {"post_id": post_id}).scalar()
        
        self.assertGreater(likes_before, 0)
        self.assertGreater(comments_before, 0)
        
        # Delete the post
        delete_query = text("DELETE FROM Posts WHERE post_id = :post_id")
        db.session.execute(delete_query, {"post_id": post_id})
        db.session.commit()
        
        # Verify likes and comments were deleted
        likes_after = db.session.execute(like_count_query, {"post_id": post_id}).scalar()
        comments_after = db.session.execute(comment_count_query, {"post_id": post_id}).scalar()
        
        self.assertEqual(likes_after, 0)
        self.assertEqual(comments_after, 0)



if __name__ == '__main__':



    unittest.main(verbosity=2)
