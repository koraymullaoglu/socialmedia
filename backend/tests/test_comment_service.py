from tests.base_test import BaseTest
from api.services.comment_service import CommentService
from api.services.post_service import PostService
from api.services.auth_service import AuthService

class TestCommentService(BaseTest):
    def setUp(self):
        super().setUp()
        self.comment_service = CommentService()
        self.post_service = PostService()
        self.auth_service = AuthService()
        
        user_res = self.auth_service.register("ctor", "c@t.com", "p")
        self.user_id = user_res['user']['user_id']
        post_res = self.post_service.create_post(self.user_id, "Post content")
        self.post_id = post_res['post']['post_id']

    def test_add_comment(self):
        res = self.comment_service.create_comment(self.post_id, self.user_id, "Nice post")
        assert res['success'] is True
        assert res['comment']['content'] == "Nice post"

    def test_reply_flow(self):
        # Root comment
        root_res = self.comment_service.create_comment(self.post_id, self.user_id, "Root")
        root_id = root_res['comment']['comment_id']
        
        # Reply via update? No, reply_to_comment
        reply_res = self.comment_service.reply_to_comment(root_id, self.user_id, "Me too")
        assert reply_res['success'] is True
        assert reply_res['comment']['parent_comment_id'] == root_id
        
        # Check replies
        replies_res = self.comment_service.get_comment_replies(root_id)
        assert replies_res['total'] == 1
        assert replies_res['replies'][0]['content'] == "Me too"

    def test_delete_ownership(self):
        res = self.comment_service.create_comment(self.post_id, self.user_id, "Mine")
        cid = res['comment']['comment_id']
        
        other_res = self.auth_service.register("hacker2", "h2@t.com", "p")
        hid = other_res['user']['user_id']
        
        # Fail
        del_res = self.comment_service.delete_comment(cid, hid)
        assert del_res['success'] is False
        
        # Success
        del_res = self.comment_service.delete_comment(cid, self.user_id)
        assert del_res['success'] is True
