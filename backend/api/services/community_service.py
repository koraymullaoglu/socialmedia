from api.repositories.community_repository import CommunityRepository
from api.entities.entities import Community
from api.permissions.permissions import has_community_permission
from typing import Optional, List, Dict, Any


class CommunityService:
    def __init__(self):
        self.community_repository = CommunityRepository()
    
    def create_community(self, name: str, description: str, creator_id: int, privacy_id: int = 1) -> Community:
        """
        Create a new community and automatically add creator as admin (role_id=1)
        """
        # Validate input
        community = Community(
            name=name,
            description=description,
            creator_id=creator_id,
            privacy_id=privacy_id
        )
        
        errors = community.validate()
        if errors:
            raise ValueError("; ".join(errors))
        
        # Create the community
        created_community = self.community_repository.create(community)
        
        # Creator is automatically added as admin by the atomic stored procedure
        pass
        
        return created_community
    
    def get_community(self, community_id: int) -> Optional[Community]:
        """Get community by ID"""
        return self.community_repository.get_by_id(community_id)
    
    def update_community(self, community_id: int, user_id: int, name: str = None, 
                        description: str = None, privacy_id: int = None) -> Community:
        """
        Update community details. Only admin can update.
        """
        # Get the community
        community = self.community_repository.get_by_id(community_id)
        if not community:
            raise ValueError("Community not found")
        
        # Check if user is a member and get their role
        member = self.community_repository.get_member(community_id, user_id)
        if not member:
            raise ValueError("You are not a member of this community")
        
        # Check if user is admin (role_id=1)
        if member.role_id != 1:
            raise ValueError("Only admins can update community details")
        
        # Update fields if provided
        if name is not None:
            community.name = name
        if description is not None:
            community.description = description
        if privacy_id is not None:
            community.privacy_id = privacy_id
        
        # Validate
        errors = community.validate()
        if errors:
            raise ValueError("; ".join(errors))
        
        return self.community_repository.update(community)
    
    def delete_community(self, community_id: int, user_id: int) -> bool:
        """
        Delete a community. Only admin can delete.
        """
        # Get the community
        community = self.community_repository.get_by_id(community_id)
        if not community:
            raise ValueError("Community not found")
        
        # Check if user is a member and get their role
        member = self.community_repository.get_member(community_id, user_id)
        if not member:
            raise ValueError("You are not a member of this community")
        
        # Check if user is admin (role_id=1)
        if member.role_id != 1:
            raise ValueError("Only admins can delete the community")
        
        return self.community_repository.delete(community_id)
    
    def join_community(self, community_id: int, user_id: int) -> Dict[str, Any]:
        """
        User joins a community as a member (role_id=3)
        """
        # Check if community exists
        community = self.community_repository.get_by_id(community_id)
        if not community:
            raise ValueError("Community not found")
        
        # Check if user is already a member
        existing_member = self.community_repository.get_member(community_id, user_id)
        if existing_member:
            raise ValueError("You are already a member of this community")
        
        # Add user as member (role_id=3)
        member = self.community_repository.add_member(community_id, user_id, role_id=3)
        return member.to_dict()
    
    def leave_community(self, community_id: int, user_id: int) -> bool:
        """
        User leaves a community
        """
        # Check if community exists
        community = self.community_repository.get_by_id(community_id)
        if not community:
            raise ValueError("Community not found")
        
        # Check if user is a member
        member = self.community_repository.get_member(community_id, user_id)
        if not member:
            raise ValueError("You are not a member of this community")
        
        # Don't allow creator/admin to leave if they are the only admin
        if member.role_id == 1:  # admin
            # Count how many admins are in the community
            members = self.community_repository.get_members(community_id, limit=1000)
            admin_count = sum(1 for m in members if m.get('role_id') == 1)
            
            if admin_count == 1:
                raise ValueError("You are the only admin. Assign another admin before leaving or delete the community")
        
        return self.community_repository.remove_member(community_id, user_id)
    
    def remove_member(self, community_id: int, user_id: int, target_user_id: int) -> bool:
        """
        Remove a member from community. Only admin or moderator can remove members.
        """
        # Check if community exists
        community = self.community_repository.get_by_id(community_id)
        if not community:
            raise ValueError("Community not found")
        
        # Check if requester is a member and get their role
        requester_member = self.community_repository.get_member(community_id, user_id)
        if not requester_member:
            raise ValueError("You are not a member of this community")
        
        # Check permissions: only admin (role_id=1) or moderator (role_id=2) can remove members
        if requester_member.role_id not in [1, 2]:
            raise ValueError("Only admins or moderators can remove members")
        
        # Check if target user is a member
        target_member = self.community_repository.get_member(community_id, target_user_id)
        if not target_member:
            raise ValueError("Target user is not a member of this community")
        
        # Don't allow removing the creator if they are admin
        if target_user_id == community.creator_id and target_member.role_id == 1:
            raise ValueError("Cannot remove the community creator who is an admin")
        
        # Moderators cannot remove admins
        if requester_member.role_id == 2 and target_member.role_id == 1:
            raise ValueError("Moderators cannot remove admins")
        
        return self.community_repository.remove_member(community_id, target_user_id)
    
    def change_member_role(self, community_id: int, user_id: int, target_user_id: int, new_role_id: int) -> Dict[str, Any]:
        """
        Change a member's role. Only admins can change roles.
        """
        # Validate role_id (1=admin, 2=moderator, 3=member)
        if new_role_id not in [1, 2, 3]:
            raise ValueError("Invalid role_id. Must be 1 (admin), 2 (moderator), or 3 (member)")
        
        # Check if community exists
        community = self.community_repository.get_by_id(community_id)
        if not community:
            raise ValueError("Community not found")
        
        # Check if requester is a member and get their role
        requester_member = self.community_repository.get_member(community_id, user_id)
        if not requester_member:
            raise ValueError("You are not a member of this community")
        
        # Only admin (role_id=1) can change roles
        if requester_member.role_id != 1:
            raise ValueError("Only admins can change member roles")
        
        # Check if target user is a member
        target_member = self.community_repository.get_member(community_id, target_user_id)
        if not target_member:
            raise ValueError("Target user is not a member of this community")
        
        # Don't allow changing the creator's role if they are the only admin
        if target_user_id == community.creator_id and target_member.role_id == 1:
            members = self.community_repository.get_members(community_id, limit=1000)
            admin_count = sum(1 for m in members if m.get('role_id') == 1)
            
            if admin_count == 1 and new_role_id != 1:
                raise ValueError("Cannot change role of the only admin. Assign another admin first")
        
        updated_member = self.community_repository.update_member_role(community_id, target_user_id, new_role_id)
        return updated_member.to_dict() if updated_member else None
    
    def get_members(self, community_id: int, limit: int = 50, offset: int = 0) -> List[Dict[str, Any]]:
        """Get all members of a community"""
        # Check if community exists
        community = self.community_repository.get_by_id(community_id)
        if not community:
            raise ValueError("Community not found")
        
        return self.community_repository.get_members(community_id, limit, offset)
    
    def search_communities(self, search_term: str, limit: int = 50, offset: int = 0) -> List[Community]:
        """Search communities by name or description"""
        if not search_term or len(search_term.strip()) == 0:
            raise ValueError("Search term is required")
        
        return self.community_repository.search(search_term, limit, offset)
    
    def get_all_communities(self, limit: int = 50, offset: int = 0) -> List[Community]:
        """Get all communities with pagination"""
        return self.community_repository.get_all(limit, offset)
    
    def get_user_communities(self, user_id: int) -> List[Dict[str, Any]]:
        """Get all communities a user is a member of"""
        return self.community_repository.get_user_communities(user_id)
