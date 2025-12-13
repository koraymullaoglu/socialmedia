from tests.base_test import BaseTest
from api.repositories.post_repository import PostRepository
from api.repositories.user_repository import UserRepository
from api.entities.entities import User, Post

class TestPostRepository(BaseTest):
    def setUp(self):
        super().setUp()
        self.post_repo = PostRepository()
        self.user_repo = UserRepository()
        
        # Create user for posts
        self.user = self.user_repo.create(User(username="post_tester", email="pt@e.com", password_hash="x"))

    def test_create_and_get_post(self):
        post = Post(user_id=self.user.user_id, content="Hello World")
        created = self.post_repo.create(post)
        
        assert created.post_id is not None
        assert created.content == "Hello World"
        
        fetched = self.post_repo.get_by_id(created.post_id)
        assert fetched.content == "Hello World"

    def test_like_logic(self):
        post = self.post_repo.create(Post(user_id=self.user.user_id, content="Likable"))
        
        # Another user to like
        liker = self.user_repo.create(User(username="liker", email="l@e.com", password_hash="x"))
        
        # Like
        success = self.post_repo.like_post(post.post_id, liker.user_id)
        assert success is True
        
        # Check has_liked
        assert self.post_repo.has_user_liked(post.post_id, liker.user_id) is True
        
        # Check count
        assert self.post_repo.count_likes(post.post_id) == 1
        
        # Unlike
        success = self.post_repo.unlike_post(post.post_id, liker.user_id)
        assert success is True
        assert self.post_repo.count_likes(post.post_id) == 0

    def test_get_with_stats(self):
        post = self.post_repo.create(Post(user_id=self.user.user_id, content="Stats Post"))
        liker = self.user_repo.create(User(username="liker2", email="l2@e.com", password_hash="x"))
        self.post_repo.like_post(post.post_id, liker.user_id)
        
        # Get with stats for liker
        stats = self.post_repo.get_with_stats(post.post_id, user_id=liker.user_id)
        assert stats is not None
        assert stats['like_count'] == 1
        assert stats['liked_by_user'] is True
        
        # Get with stats for non-liker (owner in this case, who hasn't liked it)
        stats_owner = self.post_repo.get_with_stats(post.post_id, user_id=self.user.user_id)
        assert stats_owner['like_count'] == 1
        assert stats_owner['liked_by_user'] is False
