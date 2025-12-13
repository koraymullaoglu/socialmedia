from tests.base_test import BaseTest
from api.services.community_service import CommunityService
from api.services.auth_service import AuthService

class TestCommunityService(BaseTest):
    def setUp(self):
        super().setUp()
        self.community_service = CommunityService()
        self.auth_service = AuthService()
        
        res = self.auth_service.register("comm_creator", "cc@t.com", "p")
        self.creator_id = res['user']['user_id']

    def test_create_automatically_adds_admin(self):
        c = self.community_service.create_community("AutoAdmin", "Desc", self.creator_id)
        
        # Check membership
        members = self.community_service.get_members(c.community_id)
        assert len(members) == 1
        assert members[0]['user_id'] == self.creator_id
        assert members[0]['role_id'] == 1  # Admin

    def test_join_leave(self):
        c = self.community_service.create_community("Joiners", "Desc", self.creator_id)
        
        # Another user
        res2 = self.auth_service.register("joiner", "j@t.com", "p")
        joiner_id = res2['user']['user_id']
        
        # Join
        self.community_service.join_community(c.community_id, joiner_id)
        members = self.community_service.get_members(c.community_id)
        assert len(members) == 2
        
        # Leave
        self.community_service.leave_community(c.community_id, joiner_id)
        members = self.community_service.get_members(c.community_id)
        assert len(members) == 1
