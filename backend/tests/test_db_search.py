from tests.base_test import BaseTest
from sqlalchemy import text
from api.extensions import db
import time

class TestDatabaseSearch(BaseTest):
    def setUp(self):
        super().setUp()
        self.connection = db.session.connection()

    def test_search_vector_trigger_users(self):
        """Test that user search_vector is automatically updated"""
        # Create user
        self.connection.execute(text("""
            INSERT INTO Users (username, email, password_hash, bio, is_private)
            VALUES ('search_test', 'search@test.com', 'hash', 'Loves Python programming', FALSE)
        """))
        self.connection.commit()
        
        # Check vector is not null
        result = self.connection.execute(text("""
            SELECT search_vector FROM Users WHERE username = 'search_test'
        """)).fetchone()
        
        assert result.search_vector is not None
        
        # Verify it matches 'python'
        match = self.connection.execute(text("""
            SELECT 1 FROM Users 
            WHERE username = 'search_test' 
            AND search_vector @@ to_tsquery('python')
        """)).fetchone()
        assert match is not None

    def test_search_vector_trigger_posts(self):
        """Test that post search_vector is automatically updated"""
        # Create user
        self.connection.execute(text("""
            INSERT INTO Users (username, email, password_hash)
            VALUES ('poster', 'poster@test.com', 'hash')
        """))
        user_id = self.connection.execute(text("SELECT user_id FROM Users WHERE username='poster'")).scalar()
        
        # Create post
        self.connection.execute(text("""
            INSERT INTO Posts (user_id, content) 
            VALUES (:uid, 'This is a post about database vectors')
        """), {"uid": user_id})
        # Check vector is not null
        row = self.connection.execute(text("""
            SELECT search_vector FROM Posts WHERE user_id = :uid
        """), {"uid": user_id}).fetchone()
        assert row.search_vector is not None

        match = self.connection.execute(text("""
            SELECT 1 FROM Posts 
            WHERE user_id = :uid 
            AND search_vector @@ to_tsquery('bilingual_tr_en', 'database')
        """), {"uid": user_id}).fetchone()
        assert match is not None

    def test_search_users_function(self):
        """Test search_users stored function"""
        # Insert test users
        self.connection.execute(text("""
            INSERT INTO Users (username, email, password_hash, bio) VALUES 
            ('alice', 'alice@t.com', 'h', 'Wonderland explorer'),
            ('bob', 'bob@t.com', 'h', 'Builder and engineer'),
            ('charlie', 'charlie@t.com', 'h', 'Just a random dude')
        """))
        self.connection.commit()
        
        # Test search
        result = self.connection.execute(text("""
            SELECT * FROM search_users('explorer', 'bilingual_tr_en')
        """)).fetchall()
        
        assert len(result) == 1
        assert result[0].username == 'alice'

    def test_search_posts_function(self):
        """Test search_posts_simple stored function"""
        # Setup
        self.connection.execute(text("""
            INSERT INTO Users (username, email, password_hash) VALUES ('u1', 'u1@t.com', 'h')
        """))
        uid = self.connection.execute(text("SELECT user_id FROM Users LIMIT 1")).scalar()
        
        self.connection.execute(text("""
            INSERT INTO Posts (user_id, content) VALUES 
            (:uid, 'First post is about SQL'),
            (:uid, 'Second post is about NoSQL'),
            (:uid, 'Third post is about GraphDB')
        """), {"uid": uid})
        self.connection.commit()
        
        # Search for SQL (should match SQL and NoSQL usually, or at least SQL)
        # to_tsquery('SQL') matches 'SQL'
        result = self.connection.execute(text("""
            SELECT * FROM search_posts_simple('SQL')
        """)).fetchall()
        
        # Should find at least the first one
        found_contents = [r.content for r in result]
        assert any("First post" in c for c in found_contents)

    def test_search_users_turkish(self):
        """Test search_users_turkish function"""
        # Insert user with Turkish chars
        self.connection.execute(text("""
            INSERT INTO Users (username, email, password_hash, bio) 
            VALUES ('mehmet', 'm@t.com', 'h', 'İstanbul ve çay sever')
        """))
        self.connection.commit()
        
        # Search using simple ASCII (should match due to config if stems match, or full word)
        # 'cay' might matches 'çay' if unaccent is enabled, but here we depend on turkish stemmer
        # Turkish stemmer: 'çay' -> 'çay'
        
        result = self.connection.execute(text("""
            SELECT * FROM search_users_turkish('çay')
        """)).fetchall()
        
        assert len(result) == 1
        assert result[0].username == 'mehmet'
