from tests.base_test import BaseTest
from api.repositories.community_repository import CommunityRepository
from api.repositories.user_repository import UserRepository
from api.entities.entities import User, Community

class TestCommunityRepository(BaseTest):
    def setUp(self):
        super().setUp()
        self.community_repo = CommunityRepository()
        self.user_repo = UserRepository()
        
        self.user = self.user_repo.create(User(username="comm_r_tester", email="crt@e.com", password_hash="x"))

    def test_create_and_get(self):
        c = Community(name="Pythonistas", description="Py Lovers", creator_id=self.user.user_id, privacy_id=1)
        created = self.community_repo.create(c)
        assert created.community_id is not None
        assert created.name == "Pythonistas"
        
        fetched = self.community_repo.get_by_id(created.community_id)
        assert fetched.name == "Pythonistas"

    def test_members(self):
        c = self.community_repo.create(Community(name="MembersTest", description="d", creator_id=self.user.user_id, privacy_id=1))
        
        # Creator should be admin automatically
        creator_member = self.community_repo.get_member(c.community_id, self.user.user_id)
        assert creator_member is not None
        assert creator_member.role_id == 1
        
        # Add another user
        u2 = self.user_repo.create(User(username="u2", email="u2@t.com", password_hash="x"))
        self.community_repo.add_member(c.community_id, u2.user_id, role_id=3)
        
        # Count
        assert self.community_repo.count_members(c.community_id) == 2
        
        # Check specific member
        member = self.community_repo.get_member(c.community_id, u2.user_id)
        assert member.role_id == 3
