from tests.base_test import BaseTest

class TestCommentController(BaseTest):
    def setUp(self):
        super().setUp()
        self.client = self.app.test_client()
        
        # Setup User & Token
        self.client.post('/api/auth/register', json={"username": "uc", "email": "uc@t.com", "password": "p"})
        r = self.client.post('/api/auth/login', json={"username": "uc", "password": "p"})
        self.token = r.get_json()['token']
        
        # Setup Post
        r = self.client.post('/api/posts', 
            headers={"Authorization": f"Bearer {self.token}"},
            json={"content": "Controller Post"}
        )
        self.post_id = r.get_json()['post']['post_id']

    def test_comment_api_flow(self):
        # 1. Create Comment
        resp = self.client.post(f'/api/posts/{self.post_id}/comments',
            headers={"Authorization": f"Bearer {self.token}"},
            json={"content": "API Comment"}
        )
        assert resp.status_code == 201
        data = resp.get_json()
        assert data['success'] is True
        comment_id = data['comment']['comment_id']
        
        # 2. Get Comments
        resp = self.client.get(f'/api/posts/{self.post_id}/comments',
            headers={"Authorization": f"Bearer {self.token}"}
        )
        assert resp.status_code == 200
        assert len(resp.get_json()['comments']) == 1
        
        # 3. Update Comment
        resp = self.client.put(f'/api/comments/{comment_id}',
            headers={"Authorization": f"Bearer {self.token}"},
            json={"content": "Updated API"}
        )
        assert resp.status_code == 200
        assert resp.get_json()['comment']['content'] == "Updated API"
        
        # 4. Delete Comment
        resp = self.client.delete(f'/api/comments/{comment_id}',
            headers={"Authorization": f"Bearer {self.token}"}
        )
        assert resp.status_code == 200
        assert resp.get_json()['success'] is True
