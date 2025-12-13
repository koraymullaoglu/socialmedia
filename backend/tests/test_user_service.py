from tests.base_test import BaseTest
from api.services.user_service import UserService
from api.services.auth_service import AuthService

class TestUserService(BaseTest):
    def setUp(self):
        super().setUp()
        self.user_service = UserService()
        self.auth_service = AuthService()

    def test_register_and_login_flow(self):
        # Register via AuthService
        reg_result = self.auth_service.register(
            username="servicetest",
            email="service@test.com",
            password="securepassword"
        )
        assert reg_result["success"] is True
        
        # Verify password hashing
        user = self.user_service.get_user(username="servicetest")
        assert user is not None
        assert user.get("password_hash") is None  # Should not return hash in dict usually?
        # Actually existing get_user implementation returns dict. 
        # API doesn't usually return sensitive info. Let's check repository entity directly if needed
        # But here we test login which verifies hash implicitly.
        
        # Login
        login_result = self.auth_service.login(
            username="servicetest",
            password="securepassword"
        )
        assert login_result["success"] is True
        assert "token" in login_result

    def test_privacy_controls(self):
        # Create a private user
        private_res = self.auth_service.register(
            username="private_u", email="p@t.com", password="x", is_private=True
        )
        p_id = private_res["user"]["user_id"]
        
        # Create a viewer
        viewer_res = self.auth_service.register(
            username="viewer_u", email="v@t.com", password="x"
        )
        v_id = viewer_res["user"]["user_id"]
        
        # Check explicit call
        can_view = self.user_service.can_view_profile(p_id, v_id)
        assert can_view is False
        
        # Check service get_user masking
        fetched_user = self.user_service.get_user(user_id=p_id, current_user_id=v_id)
        assert fetched_user["is_private"] is True
        assert fetched_user["can_view_profile"] is False
        # Bio should be missing if masked? Check implementation logic if needed.
        # Implementation: if private and cannot view -> returns only id, username, is_private
        assert "bio" not in fetched_user
