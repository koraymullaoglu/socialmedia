from sqlalchemy import text
from api.extensions import db
from api.entities.entities import Comment
from typing import Optional, List


class CommentRepository:
    def __init__(self):
        self.db = db

    def create(self, comment: Comment) -> Comment:
        """Create a new comment in the database"""
        query = text("""
            INSERT INTO Comments (post_id, user_id, content, parent_comment_id)
            VALUES (:post_id, :user_id, :content, :parent_comment_id)
            RETURNING comment_id, post_id, user_id, content, parent_comment_id, created_at, updated_at
        """)
        
        result = self.db.session.execute(query, {
            "post_id": comment.post_id,
            "user_id": comment.user_id,
            "content": comment.content,
            "parent_comment_id": comment.parent_comment_id
        })
        self.db.session.commit()
        
        row = result.fetchone()
        return Comment.from_row(row)

    def get_by_id(self, comment_id: int) -> Optional[Comment]:
        """Get comment by ID"""
        query = text("SELECT * FROM Comments WHERE comment_id = :comment_id")
        result = self.db.session.execute(query, {"comment_id": comment_id})
        row = result.fetchone()
        return Comment.from_row(row)

    def get_by_post_id(self, post_id: int, limit: int = 100, offset: int = 0) -> List[Comment]:
        """Get all top-level comments for a specific post (no parent)"""
        query = text("""
            SELECT * FROM Comments 
            WHERE post_id = :post_id AND parent_comment_id IS NULL
            ORDER BY created_at ASC 
            LIMIT :limit OFFSET :offset
        """)
        result = self.db.session.execute(query, {
            "post_id": post_id,
            "limit": limit,
            "offset": offset
        })
        return [Comment.from_row(row) for row in result.fetchall()]

    def get_by_user_id(self, user_id: int, limit: int = 50, offset: int = 0) -> List[Comment]:
        """Get all comments by a specific user"""
        query = text("""
            SELECT * FROM Comments 
            WHERE user_id = :user_id 
            ORDER BY created_at DESC 
            LIMIT :limit OFFSET :offset
        """)
        result = self.db.session.execute(query, {
            "user_id": user_id,
            "limit": limit,
            "offset": offset
        })
        return [Comment.from_row(row) for row in result.fetchall()]

    def update(self, comment: Comment) -> Optional[Comment]:
        """Update an existing comment"""
        query = text("""
            UPDATE Comments 
            SET content = :content
            WHERE comment_id = :comment_id
            RETURNING comment_id, post_id, user_id, content, parent_comment_id, created_at, updated_at
        """)
        
        result = self.db.session.execute(query, {
            "comment_id": comment.comment_id,
            "content": comment.content
        })
        self.db.session.commit()
        
        row = result.fetchone()
        return Comment.from_row(row)

    def delete(self, comment_id: int) -> bool:
        """Delete a comment by ID"""
        query = text("DELETE FROM Comments WHERE comment_id = :comment_id RETURNING comment_id")
        result = self.db.session.execute(query, {"comment_id": comment_id})
        self.db.session.commit()
        return result.fetchone() is not None

    def count_by_post_id(self, post_id: int) -> int:
        """Count top-level comments for a specific post"""
        query = text("SELECT COUNT(*) FROM Comments WHERE post_id = :post_id AND parent_comment_id IS NULL")
        result = self.db.session.execute(query, {"post_id": post_id})
        return result.scalar()

    def get_replies(self, comment_id: int, limit: int = 100, offset: int = 0) -> List[Comment]:
        """Get all replies to a specific comment"""
        query = text("""
            SELECT * FROM Comments 
            WHERE parent_comment_id = :comment_id 
            ORDER BY created_at ASC 
            LIMIT :limit OFFSET :offset
        """)
        result = self.db.session.execute(query, {
            "comment_id": comment_id,
            "limit": limit,
            "offset": offset
        })
        return [Comment.from_row(row) for row in result.fetchall()]

    def count_replies(self, comment_id: int) -> int:
        """Count replies to a specific comment"""
        query = text("SELECT COUNT(*) FROM Comments WHERE parent_comment_id = :comment_id")
        result = self.db.session.execute(query, {"comment_id": comment_id})
        return result.scalar()
