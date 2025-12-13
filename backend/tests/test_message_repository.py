from tests.base_test import BaseTest
from api.repositories.message_repository import MessageRepository
from api.repositories.user_repository import UserRepository
from api.entities.entities import User, Message

class TestMessageRepository(BaseTest):
    def setUp(self):
        super().setUp()
        self.message_repo = MessageRepository()
        self.user_repo = UserRepository()
        
        self.sender = self.user_repo.create(User(username="msgSender", email="ms@e.com", password_hash="x"))
        self.receiver = self.user_repo.create(User(username="msgReceiver", email="mr@e.com", password_hash="x"))

    def test_create_and_get(self):
        msg = Message(sender_id=self.sender.user_id, receiver_id=self.receiver.user_id, content="Hi")
        created = self.message_repo.create(msg)
        assert created.message_id is not None
        
        # Unread count
        assert self.message_repo.get_unread_count(self.receiver.user_id) == 1
        
        # Mark read
        self.message_repo.mark_as_read(created.message_id)
        assert self.message_repo.get_unread_count(self.receiver.user_id) == 0

    def test_conversation(self):
        self.message_repo.create(Message(sender_id=self.sender.user_id, receiver_id=self.receiver.user_id, content="1"))
        self.message_repo.create(Message(sender_id=self.receiver.user_id, receiver_id=self.sender.user_id, content="2"))
        
        msgs = self.message_repo.get_conversation(self.sender.user_id, self.receiver.user_id)
        assert len(msgs) == 2
