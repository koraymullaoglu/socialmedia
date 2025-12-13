from tests.base_test import BaseTest

class TestCommunityController(BaseTest):
    def setUp(self):
        super().setUp()
        self.client = self.app.test_client()
        
        # User 1 (Creator)
        self.client.post('/api/auth/register', json={"username": "c1", "email": "c1@t.com", "password": "p"})
        r = self.client.post('/api/auth/login', json={"username": "c1", "password": "p"})
        self.token1 = r.get_json()['token']
        
        # User 2 (Joiner)
        self.client.post('/api/auth/register', json={"username": "c2", "email": "c2@t.com", "password": "p"})
        r = self.client.post('/api/auth/login', json={"username": "c2", "password": "p"})
        self.token2 = r.get_json()['token']

    def test_community_api_lifecycle(self):
        # 1. Create
        resp = self.client.post('/api/communities',
            headers={"Authorization": f"Bearer {self.token1}"},
            json={"name": "API Comm", "description": "Desc"}
        )
        assert resp.status_code == 201
        cid = resp.get_json()['community']['community_id']
        
        # 2. Join (U2)
        resp = self.client.post(f'/api/communities/{cid}/join',
            headers={"Authorization": f"Bearer {self.token2}"}
        )
        assert resp.status_code == 201
        
        # 3. Get Members
        resp = self.client.get(f'/api/communities/{cid}/members',
            headers={"Authorization": f"Bearer {self.token1}"}
        )
        assert resp.status_code == 200
        assert len(resp.get_json()['members']) == 2
