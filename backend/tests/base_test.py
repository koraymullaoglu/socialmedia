import unittest
from api.extensions import db
from sqlalchemy import text
from app import app

class BaseTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        """Set up test application context once for the class"""
        cls.app = app
        cls.app.config['TESTING'] = True
        cls.app.config['SQLALCHEMY_DATABASE_URI'] = app.config['SQLALCHEMY_DATABASE_URI']
        cls.app_context = cls.app.app_context()
        cls.app_context.push()

    @classmethod
    def tearDownClass(cls):
        """Remove application context"""
        cls.app_context.pop()

    def setUp(self):
        """Run before each test"""
        # Clean up database
        self._clear_data()
        
    def _clear_data(self):
        # Truncate all data tables but keep lookup tables (Roles, PrivacyTypes, FollowStatus)
        # We use CASCADE to handle foreign keys
        tables = [
            "Comments", "Messages", "Posts", "CommunityMembers", 
            "Follows", "Communities", "AuditLog", "Users"
        ]
        
        with db.engine.connect() as conn:
            # Disable triggers temporarily if needed? No, CASCADE should filter down.
            # Actually, order might matter if not using CASCADE? RESTART IDENTITY CASCADE handles everything.
            # But we need to be careful not to delete Roles if Users reference them?
            # Users reference Roles? No, UserRoles? 
            # Users table doesn't reference Roles directly? 
            # Let's check init.sql if I could.
            # Users has role_id? 
            # If Users has FK to Roles, Truncating Users is fine. Roles stays.
            
            # Construct single truncate command
            table_str = ", ".join(tables)
            conn.execute(text(f"TRUNCATE TABLE {table_str} RESTART IDENTITY CASCADE"))
            conn.commit()

    def tearDown(self):
        """Run after each test"""
        db.session.remove()
