from tests.base_test import BaseTest

class TestFollowController(BaseTest):
    def setUp(self):
        super().setUp()
        self.client = self.app.test_client()
        
        # U1 Token
        self.client.post('/api/auth/register', json={"username": "u1", "email": "u1@e.com", "password": "p"})
        r = self.client.post('/api/auth/login', json={"username": "u1", "password": "p"})
        self.token1 = r.get_json()['token']
        self.id1 = r.get_json()['user']['user_id']
        
        # U2 Token
        self.client.post('/api/auth/register', json={"username": "u2", "email": "u2@e.com", "password": "p"})
        r = self.client.post('/api/auth/login', json={"username": "u2", "password": "p"})
        self.token2 = r.get_json()['token']
        self.id2 = r.get_json()['user']['user_id']

    def test_follow_api(self):
        # U1 follows U2
        resp = self.client.post(f'/api/users/{self.id2}/follow',
            headers={"Authorization": f"Bearer {self.token1}"}
        )
        assert resp.status_code == 201
        
        # Check Following list of U1
        resp = self.client.get(f'/api/users/{self.id1}/following',
            headers={"Authorization": f"Bearer {self.token1}"}
        )
        assert resp.status_code == 200
        following = resp.get_json()['following']
        assert len(following) == 1
        assert following[0]['user_id'] == self.id2
        
        # Unfollow
        resp = self.client.delete(f'/api/users/{self.id2}/follow',
            headers={"Authorization": f"Bearer {self.token1}"}
        )
        assert resp.status_code == 200
