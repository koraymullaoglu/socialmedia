from sqlalchemy import text
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from api.extensions import db
from api.entities.entities import User
from typing import Optional, List


class UserRepository:
    def __init__(self):
        self.db = db

    def create(self, user: User) -> User:
        """Create a new user in the database"""
        try:
            query = text("""
                INSERT INTO Users (username, email, password_hash, bio, profile_picture_url, is_private)
                VALUES (:username, :email, :password_hash, :bio, :profile_picture_url, :is_private)
                RETURNING user_id, username, email, password_hash, bio, profile_picture_url, is_private, created_at, updated_at
            """)
            
            result = self.db.session.execute(query, {
                "username": user.username,
                "email": user.email,
                "password_hash": user.password_hash,
                "bio": user.bio,
                "profile_picture_url": user.profile_picture_url,
                "is_private": user.is_private
            })
            self.db.session.commit()
            return User.from_row(result.fetchone())
        except IntegrityError:
            self.db.session.rollback()
            raise ValueError("Username or email already exists")
        except SQLAlchemyError:
            self.db.session.rollback()
            raise

    def get_by_id(self, user_id: int) -> Optional[User]:
        """Get user by ID"""
        query = text("SELECT * FROM Users WHERE user_id = :user_id")
        result = self.db.session.execute(query, {"user_id": user_id})
        return User.from_row(result.fetchone())

    def get_by_email(self, email: str) -> Optional[User]:
        """Get user by email"""
        query = text("SELECT * FROM Users WHERE email = :email")
        result = self.db.session.execute(query, {"email": email})
        return User.from_row(result.fetchone())

    def get_by_username(self, username: str) -> Optional[User]:
        """Get user by username"""
        query = text("SELECT * FROM Users WHERE username = :username")
        result = self.db.session.execute(query, {"username": username})
        return User.from_row(result.fetchone())

    def update(self, user: User) -> Optional[User]:
        """Update an existing user"""
        try:
            query = text("""
                UPDATE Users 
                SET username = :username,
                    email = :email,
                    password_hash = :password_hash,
                    bio = :bio,
                    profile_picture_url = :profile_picture_url,
                    is_private = :is_private
                WHERE user_id = :user_id
                RETURNING user_id, username, email, password_hash, bio, profile_picture_url, is_private, created_at, updated_at
            """)
            
            result = self.db.session.execute(query, {
                "user_id": user.user_id,
                "username": user.username,
                "email": user.email,
                "password_hash": user.password_hash,
                "bio": user.bio,
                "profile_picture_url": user.profile_picture_url,
                "is_private": user.is_private
            })
            self.db.session.commit()
            return User.from_row(result.fetchone())
        except IntegrityError:
            self.db.session.rollback()
            raise ValueError("Username or email already exists")
        except SQLAlchemyError:
            self.db.session.rollback()
            raise

    def delete(self, user_id: int) -> bool:
        """Delete a user by ID"""
        query = text("DELETE FROM Users WHERE user_id = :user_id RETURNING user_id")
        result = self.db.session.execute(query, {"user_id": user_id})
        self.db.session.commit()
        return result.fetchone() is not None

    def get_all(self, limit: int = 100, offset: int = 0) -> List[User]:
        """Get all users with pagination"""
        query = text("""
            SELECT * FROM Users 
            ORDER BY created_at DESC 
            LIMIT :limit OFFSET :offset
        """)
        result = self.db.session.execute(query, {"limit": limit, "offset": offset})
        return [User.from_row(row) for row in result.fetchall()]

    def search(self, query_str: str, limit: int = 20) -> List[User]:
        """Search users by username using Full Text Search"""
        query = text("SELECT * FROM search_users(:search, 'english', :limit)")
        result = self.db.session.execute(query, {"search": query_str, "limit": limit})
        return [User.from_row(row) for row in result.fetchall()]

    def count(self) -> int:
        """Get total user count"""
        query = text("SELECT COUNT(*) FROM Users")
        return self.db.session.execute(query).scalar()

    def exists_by_email(self, email: str) -> bool:
        """Check if email exists"""
        query = text("SELECT EXISTS(SELECT 1 FROM Users WHERE email = :email)")
        return self.db.session.execute(query, {"email": email}).scalar()

    def exists_by_username(self, username: str) -> bool:
        """Check if username exists"""
        query = text("SELECT EXISTS(SELECT 1 FROM Users WHERE username = :username)")
        return self.db.session.execute(query, {"username": username}).scalar()

    def get_recommendations(self, user_id: int, limit: int = 10) -> List[dict]:
        """Get friend recommendations for a user"""
        query = text("""
            SELECT * FROM advanced_friend_recommendations 
            WHERE user_id = :user_id 
            LIMIT :limit
        """)
        
        result = self.db.session.execute(query, {
            "user_id": user_id,
            "limit": limit
        })
        
        # This view returns: 
        # user_id, suggested_friend, mutual_count, follower_count, recommendation_score, etc...
        # We might need to map it nicely or just return dicts.
        # The view selects: fs.user_id, fs.suggested_friend, fs.mutual_count, fs.recommendation_score
        # ... and joins Users u on fs.suggested_friend.
        # It doesn't seem to select username/profile_pic?
        # Let's verify view definition in init.sql if possible.
        # But for now, returning dict is safe.
        
        recommendations = []
        for row in result.fetchall():
            recommendations.append(dict(row._mapping))
            
        return recommendations
