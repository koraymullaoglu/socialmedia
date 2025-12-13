from tests.base_test import BaseTest
from api.repositories.comment_repository import CommentRepository
from api.repositories.user_repository import UserRepository
from api.repositories.post_repository import PostRepository
from api.entities.entities import User, Post, Comment

class TestCommentRepository(BaseTest):
    def setUp(self):
        super().setUp()
        self.comment_repo = CommentRepository()
        self.user_repo = UserRepository()
        self.post_repo = PostRepository()
        
        self.user = self.user_repo.create(User(username="comm_tester", email="ct@e.com", password_hash="x"))
        self.post = self.post_repo.create(Post(user_id=self.user.user_id, content="Root Post"))

    def test_create_and_get_comment(self):
        comment = Comment(post_id=self.post.post_id, user_id=self.user.user_id, content="Reply")
        created = self.comment_repo.create(comment)
        
        assert created.comment_id is not None
        assert created.content == "Reply"
        
        fetched = self.comment_repo.get_by_id(created.comment_id)
        assert fetched.content == "Reply"

    def test_replies(self):
        root_comment = self.comment_repo.create(Comment(post_id=self.post.post_id, user_id=self.user.user_id, content="RootC"))
        reply = self.comment_repo.create(Comment(post_id=self.post.post_id, user_id=self.user.user_id, content="Nested", parent_comment_id=root_comment.comment_id))
        
        replies = self.comment_repo.get_replies(root_comment.comment_id)
        assert len(replies) == 1
        assert replies[0].content == "Nested"
        assert self.comment_repo.count_replies(root_comment.comment_id) == 1

    def test_delete(self):
        c = self.comment_repo.create(Comment(post_id=self.post.post_id, user_id=self.user.user_id, content="Del"))
        assert self.comment_repo.delete(c.comment_id) is True
        assert self.comment_repo.get_by_id(c.comment_id) is None
