from tests.base_test import BaseTest
import json
from api.extensions import db
from sqlalchemy import text

class TestDiscoveryFeatures(BaseTest):
    def setUp(self):
        super().setUp()
        self.client = self.app.test_client()
        
        # Helper helpers
        self.create_user_helper("user1", "user1@example.com")
        self.user2_token = self.register_and_login("user2", "user2@example.com")
        self.user2_id = self.get_user_id_by_username("user2")

    def register_and_login(self, username, email, password="password"):
        """Register and login helper"""
        self.client.post('/api/auth/register', 
                       data=json.dumps({'username': username, 'email': email, 'password': password}),
                       content_type='application/json')
        response = self.client.post('/api/auth/login', 
                                  data=json.dumps({'username': username, 'password': password}),
                                  content_type='application/json')
        return json.loads(response.data)['token']

    def create_user_helper(self, username, email):
        """Just register without login"""
        self.client.post('/api/auth/register', 
                       data=json.dumps({'username': username, 'email': email, 'password': "password"}),
                       content_type='application/json')
    
    def get_user_id_by_username(self, username):
        with self.app.app_context():
            result = db.session.execute(text("SELECT user_id FROM Users WHERE username=:u"), {"u": username}).fetchone()
            return result[0]

    def test_discover_feed(self):
        """Test the popular posts endpoint"""
        # Create a post as user1
        user1_token = self.register_and_login("user1_login", "user1_login@example.com")
        
        create_resp = self.client.post('/api/posts', 
                       data=json.dumps({'content': 'Popular Content'}),
                       content_type='application/json',
                       headers={'Authorization': f'Bearer {user1_token}'})
        
        post_id = json.loads(create_resp.data)['post']['post_id']

        # Like it as user2
        self.client.post(f'/api/posts/{post_id}/like', 
                        headers={'Authorization': f'Bearer {self.user2_token}'})

        # Get discover feed
        response = self.client.get('/api/posts/discover',
                                 headers={'Authorization': f'Bearer {self.user2_token}'})
        
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertTrue(data['success'])
        self.assertTrue(len(data['posts']) > 0)
        
        # Verify extra fields from view exist
        first_post = data['posts'][0]
        self.assertIn('like_count', first_post)
        self.assertIn('engagement_score', first_post)

    def test_friend_recommendations(self):
        """Test friend recommendations"""
        # Setup: user1 -> follows -> user2
        # user3 -> follows -> user2
        
        user3_token = self.register_and_login("user3", "user3@example.com")
        user3_id = self.get_user_id_by_username("user3")
        
        user1_token = self.register_and_login("user1_rec", "user1_rec@example.com")
        
        # Make user1 follow user2
        self.client.post(f'/api/users/{self.user2_id}/follow', 
                       headers={'Authorization': f'Bearer {user1_token}'})
                       
        # Make user3 follow user2
        self.client.post(f'/api/users/{self.user2_id}/follow', 
                       headers={'Authorization': f'Bearer {user3_token}'})
        
        # Note: recommendations is under /auth because it's in user_controller
        response = self.client.get('/api/auth/users/recommendations',
                                 headers={'Authorization': f'Bearer {user3_token}'})
                                 
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertTrue(data['success'])
        self.assertIn('recommendations', data)
