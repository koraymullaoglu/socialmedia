from api.repositories.message_repository import MessageRepository
from api.repositories.user_repository import UserRepository
from api.entities.entities import Message
from typing import Dict, Any, List


class MessageService:
    def __init__(self):
        self.message_repository = MessageRepository()
        self.user_repository = UserRepository()
    
    def send_message(self, sender_id: int, receiver_id: int, content: str = None, media_url: str = None) -> Dict[str, Any]:
        """Send a message to another user"""
        # Check if trying to message self
        if sender_id == receiver_id:
            return {"success": False, "error": "Cannot send message to yourself"}
        
        # Check if receiver exists
        receiver = self.user_repository.get_by_id(receiver_id)
        if not receiver:
            return {"success": False, "error": "Receiver not found"}
        
        # Create message entity
        message = Message(
            sender_id=sender_id,
            receiver_id=receiver_id,
            content=content,
            media_url=media_url,
            is_read=False
        )
        
        # Validate message
        errors = message.validate()
        if errors:
            return {"success": False, "error": errors[0]}
        
        # Create message
        created_message = self.message_repository.create(message)
        
        return {
            "success": True,
            "message": created_message.to_dict()
        }

    def get_conversation(self, user_id: int, other_user_id: int, limit: int = 50, offset: int = 0) -> Dict[str, Any]:
        """Get conversation between current user and another user"""
        # Check if other user exists
        other_user = self.user_repository.get_by_id(other_user_id)
        if not other_user:
            return {"success": False, "error": "User not found"}
        
        messages = self.message_repository.get_conversation(user_id, other_user_id, limit, offset)
        
        return {
            "success": True,
            "messages": [msg.to_dict() for msg in messages],
            "count": len(messages),
            "other_user": {
                "user_id": other_user.user_id,
                "username": other_user.username,
                "profile_picture_url": other_user.profile_picture_url
            }
        }

    def get_conversations(self, user_id: int, limit: int = 50, offset: int = 0) -> List[Dict[str, Any]]:
        """Get all conversations for a user"""
        conversations = self.message_repository.get_user_conversations(user_id, limit, offset)
        return conversations

    def mark_as_read(self, message_id: int, user_id: int) -> Dict[str, Any]:
        """Mark a message as read (only receiver can mark)"""
        message = self.message_repository.get_by_id(message_id)
        
        if not message:
            return {"success": False, "error": "Message not found"}
        
        # Only receiver can mark message as read
        if message.receiver_id != user_id:
            return {"success": False, "error": "Only receiver can mark message as read"}
        
        if message.is_read:
            return {"success": False, "error": "Message already marked as read"}
        
        updated_message = self.message_repository.mark_as_read(message_id)
        
        return {
            "success": True,
            "message": updated_message.to_dict()
        }

    def delete_message(self, message_id: int, user_id: int) -> Dict[str, Any]:
        """Delete a message (only sender can delete)"""
        message = self.message_repository.get_by_id(message_id)
        
        if not message:
            return {"success": False, "error": "Message not found"}
        
        # Only sender can delete message
        if message.sender_id != user_id:
            return {"success": False, "error": "Only sender can delete message"}
        
        deleted = self.message_repository.delete(message_id)
        
        if deleted:
            return {"success": True, "message": "Message deleted successfully"}
        return {"success": False, "error": "Failed to delete message"}

    def get_unread_count(self, user_id: int) -> Dict[str, Any]:
        """Get count of unread messages for a user"""
        count = self.message_repository.get_unread_count(user_id)
        
        return {
            "user_id": user_id,
            "unread_count": count
        }
