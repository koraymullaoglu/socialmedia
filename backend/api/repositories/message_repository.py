from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from api.extensions import db
from api.entities.entities import Message
from typing import Optional, List


class MessageRepository:
    def __init__(self):
        self.db = db
    
    def create(self, message: Message) -> Message:
        """Create a new message"""
        try:
            query = text("""
                INSERT INTO Messages (sender_id, receiver_id, content, media_url, is_read)
                VALUES (:sender_id, :receiver_id, :content, :media_url, :is_read)
                RETURNING message_id, sender_id, receiver_id, content, media_url, is_read, created_at
            """)
            
            result = self.db.session.execute(query, {
                "sender_id": message.sender_id,
                "receiver_id": message.receiver_id,
                "content": message.content,
                "media_url": message.media_url,
                "is_read": message.is_read
            })
            self.db.session.commit()
            return Message.from_row(result.fetchone())
        except SQLAlchemyError:
            self.db.session.rollback()
            raise

    def get_by_id(self, message_id: int) -> Optional[Message]:
        """Get message by ID"""
        query = text("SELECT * FROM Messages WHERE message_id = :message_id")
        result = self.db.session.execute(query, {"message_id": message_id})
        return Message.from_row(result.fetchone())

    def get_conversation(self, user1_id: int, user2_id: int, limit: int = 50, offset: int = 0) -> List[Message]:
        """Get conversation between two users"""
        query = text("""
            SELECT * FROM Messages 
            WHERE (sender_id = :user1_id AND receiver_id = :user2_id)
               OR (sender_id = :user2_id AND receiver_id = :user1_id)
            ORDER BY created_at DESC
            LIMIT :limit OFFSET :offset
        """)
        result = self.db.session.execute(query, {
            "user1_id": user1_id,
            "user2_id": user2_id,
            "limit": limit,
            "offset": offset
        })
        return [Message.from_row(row) for row in result.fetchall()]

    def get_user_conversations(self, user_id: int, limit: int = 50, offset: int = 0) -> List[dict]:
        """Get all conversations for a user with last message"""
        query = text("""
            WITH ranked_messages AS (
                SELECT 
                    m.*,
                    CASE 
                        WHEN m.sender_id = :user_id THEN m.receiver_id 
                        ELSE m.sender_id 
                    END as other_user_id,
                    ROW_NUMBER() OVER (
                        PARTITION BY CASE 
                            WHEN m.sender_id = :user_id THEN m.receiver_id 
                            ELSE m.sender_id 
                        END 
                        ORDER BY m.created_at DESC
                    ) as rn
                FROM Messages m
                WHERE m.sender_id = :user_id OR m.receiver_id = :user_id
            )
            SELECT 
                rm.*,
                u.username,
                u.profile_picture_url
            FROM ranked_messages rm
            JOIN Users u ON rm.other_user_id = u.user_id
            WHERE rm.rn = 1
            ORDER BY rm.created_at DESC
            LIMIT :limit OFFSET :offset
        """)
        result = self.db.session.execute(query, {
            "user_id": user_id,
            "limit": limit,
            "offset": offset
        })
        return [dict(row._mapping) for row in result.fetchall()]

    def mark_as_read(self, message_id: int) -> Optional[Message]:
        """Mark a single message as read"""
        try:
            query = text("""
                UPDATE Messages 
                SET is_read = TRUE
                WHERE message_id = :message_id
                RETURNING message_id, sender_id, receiver_id, content, media_url, is_read, created_at
            """)
            
            result = self.db.session.execute(query, {"message_id": message_id})
            self.db.session.commit()
            return Message.from_row(result.fetchone())
        except SQLAlchemyError:
            self.db.session.rollback()
            raise

    def mark_conversation_as_read(self, receiver_id: int, sender_id: int) -> int:
        """Mark all messages in a conversation as read"""
        try:
            query = text("""
                UPDATE Messages 
                SET is_read = TRUE
                WHERE receiver_id = :receiver_id AND sender_id = :sender_id AND is_read = FALSE
                RETURNING message_id
            """)
            
            result = self.db.session.execute(query, {
                "receiver_id": receiver_id,
                "sender_id": sender_id
            })
            self.db.session.commit()
            return len(result.fetchall())
        except SQLAlchemyError:
            self.db.session.rollback()
            raise

    def delete(self, message_id: int) -> bool:
        """Delete a message"""
        query = text("""
            DELETE FROM Messages 
            WHERE message_id = :message_id
            RETURNING message_id
        """)
        result = self.db.session.execute(query, {"message_id": message_id})
        self.db.session.commit()
        return result.fetchone() is not None

    def get_unread_count(self, user_id: int) -> int:
        """Get count of unread messages for a user"""
        query = text("""
            SELECT COUNT(*) as count 
            FROM Messages 
            WHERE receiver_id = :user_id AND is_read = FALSE
        """)
        result = self.db.session.execute(query, {"user_id": user_id})
        row = result.fetchone()
        return row.count if row else 0
