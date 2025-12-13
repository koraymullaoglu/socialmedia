from tests.base_test import BaseTest
from api.repositories.user_repository import UserRepository
from api.entities.entities import User
from sqlalchemy import text
from api.extensions import db
import time

class TestUserRepository(BaseTest):
    def setUp(self):
        super().setUp()
        self.repo = UserRepository()

    def test_create_and_get_user(self):
        user = User(
            username="testrepo",
            email="testrepo@example.com",
            password_hash="hash",
            bio="bio",
            is_private=False
        )
        created_user = self.repo.create(user)
        assert created_user.user_id is not None
        assert created_user.username == "testrepo"
        assert created_user.created_at is not None

        fetched = self.repo.get_by_id(created_user.user_id)
        assert fetched is not None
        assert fetched.username == "testrepo"

    def test_update_updates_timestamp(self):
        user = User(username="updater", email="update@example.com", password_hash="h")
        created = self.repo.create(user)
        original_ts = created.updated_at
        
        # Ensure time passes if originally generated same timestamp
        time.sleep(0.1)
        
        created.bio = "New Bio"
        updated = self.repo.update(created)
        
        assert updated.bio == "New Bio"
        assert updated.updated_at is not None
        if original_ts:
            assert updated.updated_at > original_ts

    def test_search_users(self):
        # Create users for search
        u1 = self.repo.create(User(username="search_python", email="s1@e.com", password_hash="x"))
        u2 = self.repo.create(User(username="search_java", email="s2@e.com", password_hash="x"))
        
        # Simple search using ILIKE logic in repo
        results = self.repo.search("python")
        assert len(results) >= 1
        usernames = [u.username for u in results]
        assert "search_python" in usernames
        assert "search_java" not in usernames
