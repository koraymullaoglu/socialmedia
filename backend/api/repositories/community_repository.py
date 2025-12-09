from sqlalchemy import text
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from api.extensions import db
from api.entities.entities import Community, CommunityMember
from typing import Optional, List


class CommunityRepository:
    def __init__(self):
        self.db = db
    
    def create(self, community: Community) -> Community:
        """Create a new community in the database"""
        try:
            query = text("""
                INSERT INTO Communities (name, description, creator_id, privacy_id)
                VALUES (:name, :description, :creator_id, :privacy_id)
                RETURNING community_id, name, description, creator_id, privacy_id, created_at
            """)
            
            result = self.db.session.execute(query, {
                "name": community.name,
                "description": community.description,
                "creator_id": community.creator_id,
                "privacy_id": community.privacy_id
            })
            self.db.session.commit()
            return Community.from_row(result.fetchone())
        except IntegrityError:
            self.db.session.rollback()
            raise ValueError("Community name already exists")
        except SQLAlchemyError:
            self.db.session.rollback()
            raise
    
    def get_by_id(self, community_id: int) -> Optional[Community]:
        """Get community by ID"""
        query = text("SELECT * FROM Communities WHERE community_id = :community_id")
        result = self.db.session.execute(query, {"community_id": community_id})
        return Community.from_row(result.fetchone())
    
    def get_all(self, limit: int = 50, offset: int = 0) -> List[Community]:
        """Get all communities with pagination"""
        query = text("""
            SELECT * FROM Communities 
            ORDER BY created_at DESC 
            LIMIT :limit OFFSET :offset
        """)
        result = self.db.session.execute(query, {"limit": limit, "offset": offset})
        return [Community.from_row(row) for row in result.fetchall()]
    
    def search(self, search_term: str, limit: int = 50, offset: int = 0) -> List[Community]:
        """Search communities by name or description"""
        query = text("""
            SELECT * FROM Communities 
            WHERE name ILIKE :search_term OR description ILIKE :search_term
            ORDER BY created_at DESC 
            LIMIT :limit OFFSET :offset
        """)
        result = self.db.session.execute(query, {
            "search_term": f"%{search_term}%",
            "limit": limit,
            "offset": offset
        })
        return [Community.from_row(row) for row in result.fetchall()]
    
    def update(self, community: Community) -> Optional[Community]:
        """Update an existing community"""
        try:
            query = text("""
                UPDATE Communities 
                SET name = :name,
                    description = :description,
                    privacy_id = :privacy_id
                WHERE community_id = :community_id
                RETURNING community_id, name, description, creator_id, privacy_id, created_at
            """)
            
            result = self.db.session.execute(query, {
                "community_id": community.community_id,
                "name": community.name,
                "description": community.description,
                "privacy_id": community.privacy_id
            })
            self.db.session.commit()
            return Community.from_row(result.fetchone())
        except IntegrityError:
            self.db.session.rollback()
            raise ValueError("Community name already exists")
        except SQLAlchemyError:
            self.db.session.rollback()
            raise
    
    def delete(self, community_id: int) -> bool:
        """Delete a community by ID"""
        query = text("DELETE FROM Communities WHERE community_id = :community_id RETURNING community_id")
        result = self.db.session.execute(query, {"community_id": community_id})
        self.db.session.commit()
        return result.fetchone() is not None
    
    def add_member(self, community_id: int, user_id: int, role_id: int) -> CommunityMember:
        """Add a member to a community with a specific role"""
        try:
            query = text("""
                INSERT INTO CommunityMembers (community_id, user_id, role_id)
                VALUES (:community_id, :user_id, :role_id)
                RETURNING community_id, user_id, role_id, joined_at
            """)
            
            result = self.db.session.execute(query, {
                "community_id": community_id,
                "user_id": user_id,
                "role_id": role_id
            })
            self.db.session.commit()
            return CommunityMember.from_row(result.fetchone())
        except IntegrityError:
            self.db.session.rollback()
            raise ValueError("User is already a member of this community")
        except SQLAlchemyError:
            self.db.session.rollback()
            raise
    
    def remove_member(self, community_id: int, user_id: int) -> bool:
        """Remove a member from a community"""
        query = text("""
            DELETE FROM CommunityMembers 
            WHERE community_id = :community_id AND user_id = :user_id 
            RETURNING user_id
        """)
        result = self.db.session.execute(query, {
            "community_id": community_id,
            "user_id": user_id
        })
        self.db.session.commit()
        return result.fetchone() is not None
    
    def update_member_role(self, community_id: int, user_id: int, role_id: int) -> Optional[CommunityMember]:
        """Update a member's role in a community"""
        try:
            query = text("""
                UPDATE CommunityMembers 
                SET role_id = :role_id
                WHERE community_id = :community_id AND user_id = :user_id
                RETURNING community_id, user_id, role_id, joined_at
            """)
            
            result = self.db.session.execute(query, {
                "community_id": community_id,
                "user_id": user_id,
                "role_id": role_id
            })
            self.db.session.commit()
            return CommunityMember.from_row(result.fetchone())
        except SQLAlchemyError:
            self.db.session.rollback()
            raise
    
    def get_members(self, community_id: int, limit: int = 50, offset: int = 0) -> List[dict]:
        """Get all members of a community with user and role details"""
        query = text("""
            SELECT 
                cm.community_id, cm.user_id, cm.role_id, cm.joined_at,
                u.username, u.email, u.bio, u.profile_picture_url,
                r.role_name
            FROM CommunityMembers cm
            JOIN Users u ON cm.user_id = u.user_id
            JOIN Roles r ON cm.role_id = r.role_id
            WHERE cm.community_id = :community_id
            ORDER BY cm.joined_at DESC
            LIMIT :limit OFFSET :offset
        """)
        result = self.db.session.execute(query, {
            "community_id": community_id,
            "limit": limit,
            "offset": offset
        })
        return [dict(row._mapping) for row in result.fetchall()]
    
    def get_member(self, community_id: int, user_id: int) -> Optional[CommunityMember]:
        """Get a specific member of a community"""
        query = text("""
            SELECT * FROM CommunityMembers 
            WHERE community_id = :community_id AND user_id = :user_id
        """)
        result = self.db.session.execute(query, {
            "community_id": community_id,
            "user_id": user_id
        })
        return CommunityMember.from_row(result.fetchone())
    
    def get_user_communities(self, user_id: int) -> List[dict]:
        """Get all communities a user is a member of"""
        query = text("""
            SELECT 
                c.community_id, c.name, c.description, c.creator_id, c.privacy_id, c.created_at,
                cm.role_id, cm.joined_at,
                r.role_name
            FROM CommunityMembers cm
            JOIN Communities c ON cm.community_id = c.community_id
            JOIN Roles r ON cm.role_id = r.role_id
            WHERE cm.user_id = :user_id
            ORDER BY cm.joined_at DESC
        """)
        result = self.db.session.execute(query, {"user_id": user_id})
        return [dict(row._mapping) for row in result.fetchall()]
    
    def count_members(self, community_id: int) -> int:
        """Count the number of members in a community"""
        query = text("""
            SELECT COUNT(*) as count FROM CommunityMembers 
            WHERE community_id = :community_id
        """)
        result = self.db.session.execute(query, {"community_id": community_id})
        row = result.fetchone()
        return row.count if row else 0
