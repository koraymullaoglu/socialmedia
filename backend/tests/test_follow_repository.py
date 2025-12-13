from tests.base_test import BaseTest
from api.repositories.follow_repository import FollowRepository
from api.repositories.user_repository import UserRepository
from api.entities.entities import User, Follow

class TestFollowRepository(BaseTest):
    def setUp(self):
        super().setUp()
        self.follow_repo = FollowRepository()
        self.user_repo = UserRepository()
        
        self.u1 = self.user_repo.create(User(username="f1", email="f1@e.com", password_hash="x"))
        self.u2 = self.user_repo.create(User(username="f2", email="f2@e.com", password_hash="x"))

    def test_create_and_get(self):
        f = Follow(follower_id=self.u1.user_id, following_id=self.u2.user_id, status_id=2)
        created = self.follow_repo.create(f)
        
        fetched = self.follow_repo.get_by_ids(self.u1.user_id, self.u2.user_id)
        assert fetched is not None
        assert fetched.status_id == 2

    def test_update_status(self):
        f = Follow(follower_id=self.u1.user_id, following_id=self.u2.user_id, status_id=1) # Pending
        self.follow_repo.create(f)
        
        updated = self.follow_repo.update_status(self.u1.user_id, self.u2.user_id, 2) # Accept
        assert updated.status_id == 2
        
        fetched = self.follow_repo.get_by_ids(self.u1.user_id, self.u2.user_id)
        assert fetched.status_id == 2

    def test_counts(self):
        f = Follow(follower_id=self.u1.user_id, following_id=self.u2.user_id, status_id=2)
        self.follow_repo.create(f)
        
        assert self.follow_repo.count_followers(self.u2.user_id) == 1
        assert self.follow_repo.count_following(self.u1.user_id) == 1
