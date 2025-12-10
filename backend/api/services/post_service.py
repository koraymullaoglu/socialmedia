from api.repositories.post_repository import PostRepository
from api.repositories.user_repository import UserRepository
from api.repositories.follow_repository import FollowRepository
from api.entities.entities import Post
from typing import Optional, Dict, Any, List


class PostService:
    def __init__(self):
        self.post_repository = PostRepository()
        self.user_repository = UserRepository()
        self.follow_repository = FollowRepository()

    def create_post(self, user_id: int, content: str = None, 
                    media_url: str = None, community_id: int = None) -> Dict[str, Any]:
        """Create a new post with validation"""
        # Create post entity
        post = Post(
            user_id=user_id,
            content=content,
            media_url=media_url,
            community_id=community_id
        )
        
        # Validate content
        errors = post.validate()
        if errors:
            return {"success": False, "errors": errors}
        
        # Save to database
        created_post = self.post_repository.create(post)
        
        return {
            "success": True,
            "post": created_post.to_dict()
        }

    def get_post(self, post_id: int, user_id: Optional[int] = None) -> Optional[Dict[str, Any]]:
        """Get post by ID with like count and user's like status (with privacy check)"""
        post = self.post_repository.get_by_id(post_id)
        if post:
            # Check if user can view this post
            if user_id and not self.can_view_post(post, user_id):
                return None
            
            post_dict = post.to_dict()
            post_dict['like_count'] = self.post_repository.count_likes(post_id)
            if user_id:
                post_dict['liked_by_user'] = self.post_repository.has_user_liked(post_id, user_id)
            return post_dict
        return None

    def get_user_posts(self, user_id: int, current_user_id: int = None, limit: int = 50, offset: int = 0) -> Dict[str, Any]:
        """Get all posts by a specific user (filtered by privacy)"""
        # Check if current user can view this user's posts
        if current_user_id and current_user_id != user_id:
            post_author = self.user_repository.get_by_id(user_id)
            if post_author and post_author.is_private:
                # Check if current user is an accepted follower
                follow = self.follow_repository.get_by_ids(current_user_id, user_id)
                if not follow or follow.status_id != 2:
                    return {
                        "posts": [],
                        "total": 0,
                        "limit": limit,
                        "offset": offset,
                        "message": "This account is private"
                    }
        
        posts = self.post_repository.get_by_user_id(user_id, limit, offset)
        total = self.post_repository.count(user_id=user_id)
        
        return {
            "posts": [post.to_dict() for post in posts],
            "total": total,
            "limit": limit,
            "offset": offset
        }

    def get_community_posts(self, community_id: int, limit: int = 50, offset: int = 0) -> Dict[str, Any]:
        """Get all posts in a specific community"""
        posts = self.post_repository.get_by_community_id(community_id, limit, offset)
        total = self.post_repository.count(community_id=community_id)
        
        return {
            "posts": [post.to_dict() for post in posts],
            "total": total,
            "limit": limit,
            "offset": offset
        }

    def update_post(self, post_id: int, user_id: int, updates: Dict[str, Any]) -> Dict[str, Any]:
        """Update a post with ownership validation"""
        # Get existing post
        post = self.post_repository.get_by_id(post_id)
        if not post:
            return {"success": False, "error": "Post not found"}
        
        # Ownership validation
        if post.user_id != user_id:
            return {"success": False, "error": "You can only edit your own posts"}
        
        # Apply updates
        if "content" in updates:
            post.content = updates["content"]
        if "media_url" in updates:
            post.media_url = updates["media_url"]
        if "community_id" in updates:
            post.community_id = updates["community_id"]
        
        # Validate updated post
        errors = post.validate()
        if errors:
            return {"success": False, "errors": errors}
        
        # Save updates
        updated_post = self.post_repository.update(post)
        
        return {
            "success": True,
            "post": updated_post.to_dict()
        }

    def delete_post(self, post_id: int, user_id: int) -> Dict[str, Any]:
        """Delete a post with ownership validation"""
        # Get existing post
        post = self.post_repository.get_by_id(post_id)
        if not post:
            return {"success": False, "error": "Post not found"}
        
        # Ownership validation
        if post.user_id != user_id:
            return {"success": False, "error": "You can only delete your own posts"}
        
        # Delete post
        deleted = self.post_repository.delete(post_id)
        
        if deleted:
            return {"success": True, "message": "Post deleted successfully"}
        return {"success": False, "error": "Failed to delete post"}

    def get_feed(self, user_id: int, limit: int = 50, offset: int = 0) -> Dict[str, Any]:
        """Get authenticated user's feed (posts from accepted follows only)"""
        # Get all accepted follows
        following = self.follow_repository.get_following(user_id, limit=1000)
        
        # Get posts only from public users and accepted private follows
        posts = self.post_repository.get_feed(user_id, limit, offset)
        
        # Filter posts based on privacy (the feed query should already do this,
        # but this is an extra layer of security)
        filtered_posts = []
        for post in posts:
            post_author = self.user_repository.get_by_id(post.user_id)
            if post_author:
                # Include if: own post, public user, or accepted follow
                if (post.user_id == user_id or 
                    not post_author.is_private or 
                    self._is_accepted_follower(user_id, post.user_id)):
                    filtered_posts.append(post.to_dict())
        
        return {
            "posts": filtered_posts,
            "limit": limit,
            "offset": offset
        }

    def like_post(self, post_id: int, user_id: int) -> Dict[str, Any]:
        """Like a post with validation"""
        # Get post
        post = self.post_repository.get_by_id(post_id)
        if not post:
            return {"success": False, "error": "Post not found"}
        
        # Prevent liking own posts
        if post.user_id == user_id:
            return {"success": False, "error": "You cannot like your own posts"}
        
        # Check if already liked
        if self.post_repository.has_user_liked(post_id, user_id):
            return {"success": False, "error": "You have already liked this post"}
        
        # Add like
        success = self.post_repository.like_post(post_id, user_id)
        
        if success:
            return {
                "success": True,
                "message": "Post liked successfully",
                "like_count": self.post_repository.count_likes(post_id)
            }
        return {"success": False, "error": "Failed to like post"}

    def unlike_post(self, post_id: int, user_id: int) -> Dict[str, Any]:
        """Unlike a post"""
        # Get post
        post = self.post_repository.get_by_id(post_id)
        if not post:
            return {"success": False, "error": "Post not found"}
        
        # Check if liked
        if not self.post_repository.has_user_liked(post_id, user_id):
            return {"success": False, "error": "You have not liked this post"}
        
        # Remove like
        success = self.post_repository.unlike_post(post_id, user_id)
        
        if success:
            return {
                "success": True,
                "message": "Post unliked successfully",
                "like_count": self.post_repository.count_likes(post_id)
            }
        return {"success": False, "error": "Failed to unlike post"}

    def get_like_count(self, post_id: int) -> Dict[str, Any]:
        """Get like count for a post"""
        # Verify post exists
        post = self.post_repository.get_by_id(post_id)
        if not post:
            return {"success": False, "error": "Post not found"}
        
        count = self.post_repository.count_likes(post_id)
        return {"success": True, "like_count": count}

    def get_post_likes(self, post_id: int) -> Dict[str, Any]:
        """Get users who liked a post"""
        # Verify post exists
        post = self.post_repository.get_by_id(post_id)
        if not post:
            return {"success": False, "error": "Post not found"}
        
        likes = self.post_repository.get_post_likes(post_id)
        return {
            "success": True,
            "likes": [like.to_dict() for like in likes],
            "count": len(likes)
        }

    def can_view_post(self, post: Post, current_user_id: int) -> bool:
        """Check if current user can view a post based on privacy settings"""
        # User can always view their own posts
        if post.user_id == current_user_id:
            return True
        
        # Get post author
        post_author = self.user_repository.get_by_id(post.user_id)
        if not post_author:
            return False
        
        # If author is public, everyone can view
        if not post_author.is_private:
            return True
        
        # If author is private, check if current user is an accepted follower
        return self._is_accepted_follower(current_user_id, post.user_id)

    def _is_accepted_follower(self, follower_id: int, following_id: int) -> bool:
        """Helper method to check if user is an accepted follower"""
        follow = self.follow_repository.get_by_ids(follower_id, following_id)
        return follow is not None and follow.status_id == 2
