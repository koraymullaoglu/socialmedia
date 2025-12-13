from tests.base_test import BaseTest

class TestUserController(BaseTest):
    def setUp(self):
        super().setUp()
        self.client = self.app.test_client()

    def test_register_endpoint(self):
        resp = self.client.post('/api/auth/register', json={
            "username": "apitest",
            "email": "api@test.com",
            "password": "password123",
            "bio": "API user"
        })
        assert resp.status_code == 201
        data = resp.get_json()
        assert data["success"] is True
        assert data["user"]["username"] == "apitest"

    def test_login_endpoint(self):
        # Create user first
        self.client.post('/api/auth/register', json={
            "username": "logintest",
            "email": "login@test.com",
            "password": "password123"
        })
        
        # Login
        resp = self.client.post('/api/auth/login', json={
            "username": "logintest",
            "password": "password123"
        })
        assert resp.status_code == 200
        data = resp.get_json()
        assert "token" in data
        return data["token"]

    def test_get_me_protected_route(self):
        token = self.test_login_endpoint()
        
        # Access /api/auth/me
        resp = self.client.get('/api/auth/me', headers={
            "Authorization": f"Bearer {token}"
        })
        assert resp.status_code == 200
        data = resp.get_json()
        assert data["user"]["username"] == "logintest"
