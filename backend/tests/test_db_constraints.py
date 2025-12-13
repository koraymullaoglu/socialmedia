import unittest
from sqlalchemy import text
from api.extensions import db
from app import app
from sqlalchemy.exc import IntegrityError, DBAPIError

class TestDatabaseConstraints(unittest.TestCase):
    """Test database CHECK constraints"""

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
        """Clean up before each test"""
        # Clean up any potential leftover data
        try:
            db.session.rollback()
            db.session.execute(text("DELETE FROM Comments"))
            db.session.execute(text("DELETE FROM Messages"))
            db.session.execute(text("DELETE FROM Posts"))
            db.session.execute(text("DELETE FROM Users WHERE username LIKE 'constraint_test%'"))
            db.session.commit()
        except:
            db.session.rollback()

    def tearDown(self):
        """Clean up after each test"""
        self.setUp()

    def test_user_email_constraint(self):
        """Test valid and invalid email formats"""

        
        # Valid email
        try:
            db.session.execute(text("""
                INSERT INTO Users (username, email, password_hash)
                VALUES ('constraint_test_1', 'valid.email@example.com', 'hash')
            """))
            db.session.commit()

        except Exception as e:
            self.fail(f"Valid email failed: {e}")

        # Invalid: No @
        try:
            db.session.execute(text("""
                INSERT INTO Users (username, email, password_hash)
                VALUES ('constraint_test_2', 'invalidemail.com', 'hash')
            """))
            db.session.commit()
            self.fail("❌ Invalid email (no @) should have failed")
        except (IntegrityError, DBAPIError):
            db.session.rollback()


        # Invalid: No domain
        try:
            db.session.execute(text("""
                INSERT INTO Users (username, email, password_hash)
                VALUES ('constraint_test_3', 'user@', 'hash')
            """))
            db.session.commit()
            self.fail("❌ Invalid email (no domain) should have failed")
        except (IntegrityError, DBAPIError):
            db.session.rollback()


    def test_post_content_constraint(self):
        """Test post content/media_url requirement"""

        
        # Create user first
        db.session.execute(text("""
            INSERT INTO Users (username, email, password_hash)
            VALUES ('constraint_test_p', 'post@test.com', 'hash')
        """))
        db.session.commit()
        user_id = db.session.execute(text("SELECT user_id FROM Users WHERE username='constraint_test_p'")).scalar()

        # Valid: Content only
        try:
            db.session.execute(text("""
                INSERT INTO Posts (user_id, content) VALUES (:uid, 'Just content')
            """), {"uid": user_id})
            db.session.commit()

        except Exception as e:
            self.fail(f"Content-only post failed: {e}")

        # Valid: Media only
        try:
            db.session.execute(text("""
                INSERT INTO Posts (user_id, media_url) VALUES (:uid, 'http://example.com/img.jpg')
            """), {"uid": user_id})
            db.session.commit()

        except Exception as e:
            self.fail(f"Media-only post failed: {e}")

        # Invalid: Both empty/null
        try:
            db.session.execute(text("""
                INSERT INTO Posts (user_id, content, media_url) VALUES (:uid, NULL, NULL)
            """), {"uid": user_id})
            db.session.commit()
            self.fail("❌ Empty post should have failed")
        except (IntegrityError, DBAPIError):
            db.session.rollback()


    def test_comment_length_constraint(self):
        """Test comment minimum length constraint"""

        
        # Setup user and post
        db.session.execute(text("""
            INSERT INTO Users (username, email, password_hash)
            VALUES ('constraint_test_c', 'comment@test.com', 'hash')
        """))
        user_id = db.session.execute(text("SELECT user_id FROM Users WHERE username='constraint_test_c'")).scalar()
        
        db.session.execute(text("""
            INSERT INTO Posts (user_id, content) VALUES (:uid, 'Post content')
        """), {"uid": user_id})
        post_id = db.session.execute(text("SELECT post_id FROM Posts WHERE user_id=:uid"), {"uid": user_id}).scalar()
        db.session.commit()

        # Valid comment
        try:
            db.session.execute(text("""
                INSERT INTO Comments (post_id, user_id, content) 
                VALUES (:pid, :uid, 'Valid comment')
            """), {"pid": post_id, "uid": user_id})
            db.session.commit()

        except Exception as e:
            self.fail(f"Valid comment failed: {e}")

        # Invalid: Empty string
        try:
            db.session.execute(text("""
                INSERT INTO Comments (post_id, user_id, content) 
                VALUES (:pid, :uid, '')
            """), {"pid": post_id, "uid": user_id})
            db.session.commit()
            self.fail("❌ Empty comment should have failed")
        except (IntegrityError, DBAPIError):
            db.session.rollback()


        # Invalid: Whitespace only
        try:
            db.session.execute(text("""
                INSERT INTO Comments (post_id, user_id, content) 
                VALUES (:pid, :uid, '   ')
            """), {"pid": post_id, "uid": user_id})
            db.session.commit()
            self.fail("❌ Whitespace comment should have failed")
        except (IntegrityError, DBAPIError):
            db.session.rollback()


    def test_message_self_send_constraint(self):
        """Test message self-send constraint"""

        
        # Setup users
        db.session.execute(text("""
            INSERT INTO Users (username, email, password_hash)
            VALUES ('constraint_test_m1', 'msg1@test.com', 'hash'),
                   ('constraint_test_m2', 'msg2@test.com', 'hash')
        """))
        db.session.commit()
        u1 = db.session.execute(text("SELECT user_id FROM Users WHERE username='constraint_test_m1'")).scalar()
        u2 = db.session.execute(text("SELECT user_id FROM Users WHERE username='constraint_test_m2'")).scalar()

        # Valid: Different users
        try:
            db.session.execute(text("""
                INSERT INTO Messages (sender_id, receiver_id, content) 
                VALUES (:s, :r, 'Hello')
            """), {"s": u1, "r": u2})
            db.session.commit()

        except Exception as e:
            self.fail(f"Valid message failed: {e}")

        # Invalid: Same user
        try:
            db.session.execute(text("""
                INSERT INTO Messages (sender_id, receiver_id, content) 
                VALUES (:s, :r, 'Self talk')
            """), {"s": u1, "r": u1})
            db.session.commit()
            self.fail("❌ Self-message should have failed")
        except (IntegrityError, DBAPIError):
            db.session.rollback()


if __name__ == '__main__':
    unittest.main()
