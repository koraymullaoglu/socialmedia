from tests.base_test import BaseTest

class TestPostController(BaseTest):
    def setUp(self):
        super().setUp()
        self.client = self.app.test_client()
        
        # Register & Login User 1
        self.client.post('/api/auth/register', json={"username": "u1", "email": "u1@t.com", "password": "p"})
        r = self.client.post('/api/auth/login', json={"username": "u1", "password": "p"})
        self.token1 = r.get_json()['token']
        self.u1_id = r.get_json()['user']['user_id']
        
        # Register & Login User 2
        self.client.post('/api/auth/register', json={"username": "u2", "email": "u2@t.com", "password": "p"})
        r = self.client.post('/api/auth/login', json={"username": "u2", "password": "p"})
        self.token2 = r.get_json()['token']

    def test_create_and_get_post(self):
        # Create
        resp = self.client.post('/api/posts', 
            headers={"Authorization": f"Bearer {self.token1}"},
            json={"content": "Controller Post"}
        )
        assert resp.status_code == 201
        data = resp.get_json()
        assert data['success'] is True
        post_id = data['post']['post_id']
        
        # Get
        resp = self.client.get(f'/api/posts/{post_id}',
            headers={"Authorization": f"Bearer {self.token1}"}
        )
        assert resp.status_code == 200
        assert resp.get_json()['post']['content'] == "Controller Post"

    def test_like_unlike_api(self):
        # U1 creates
        resp = self.client.post('/api/posts', 
            headers={"Authorization": f"Bearer {self.token1}"},
            json={"content": "Like me"}
        )
        post_id = resp.get_json()['post']['post_id']
        
        # U2 likes
        resp = self.client.post(f'/api/posts/{post_id}/like',
            headers={"Authorization": f"Bearer {self.token2}"}
        )
        assert resp.status_code == 200
        assert resp.get_json()['success'] is True
        assert resp.get_json()['like_count'] == 1
        
        # U2 unlikes
        resp = self.client.delete(f'/api/posts/{post_id}/like',
            headers={"Authorization": f"Bearer {self.token2}"}
        )
        assert resp.status_code == 200
        assert resp.get_json()['like_count'] == 0
