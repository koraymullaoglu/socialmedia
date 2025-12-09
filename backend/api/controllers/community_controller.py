from flask import Blueprint, request, jsonify
from api.services.community_service import CommunityService
from api.middleware.jwt import token_required

community_bp = Blueprint('community', __name__)
community_service = CommunityService()


@community_bp.route('/communities', methods=['POST'])
@token_required
def create_community():
    """Create a new community"""
    try:
        data = request.get_json()
        
        # Validate required fields
        if not data.get('name'):
            return jsonify({"error": "Community name is required"}), 400
        
        # Get user_id from token
        user_id = request.user_id
        
        # Create community
        community = community_service.create_community(
            name=data.get('name'),
            description=data.get('description', ''),
            creator_id=user_id,
            privacy_id=data.get('privacy_id', 1)
        )
        
        return jsonify({
            "message": "Community created successfully",
            "community": community.to_dict()
        }), 201
        
    except ValueError as e:
        return jsonify({"error": str(e)}), 400
    except Exception as e:
        return jsonify({"error": "Internal server error"}), 500


@community_bp.route('/communities', methods=['GET'])
@token_required
def get_communities():
    """Get all communities with pagination"""
    try:
        limit = request.args.get('limit', 50, type=int)
        offset = request.args.get('offset', 0, type=int)
        
        # Validate pagination parameters
        if limit < 1 or limit > 100:
            return jsonify({"error": "Limit must be between 1 and 100"}), 400
        if offset < 0:
            return jsonify({"error": "Offset must be non-negative"}), 400
        
        communities = community_service.get_all_communities(limit, offset)
        
        return jsonify({
            "communities": [c.to_dict() for c in communities],
            "limit": limit,
            "offset": offset
        }), 200
        
    except Exception as e:
        return jsonify({"error": "Internal server error"}), 500


@community_bp.route('/communities/search', methods=['GET'])
@token_required
def search_communities():
    """Search communities by name or description"""
    try:
        search_term = request.args.get('q', '').strip()
        limit = request.args.get('limit', 50, type=int)
        offset = request.args.get('offset', 0, type=int)
        
        if not search_term:
            return jsonify({"error": "Search query parameter 'q' is required"}), 400
        
        # Validate pagination parameters
        if limit < 1 or limit > 100:
            return jsonify({"error": "Limit must be between 1 and 100"}), 400
        if offset < 0:
            return jsonify({"error": "Offset must be non-negative"}), 400
        
        communities = community_service.search_communities(search_term, limit, offset)
        
        return jsonify({
            "communities": [c.to_dict() for c in communities],
            "search_term": search_term,
            "limit": limit,
            "offset": offset
        }), 200
        
    except ValueError as e:
        return jsonify({"error": str(e)}), 400
    except Exception as e:
        return jsonify({"error": "Internal server error"}), 500


@community_bp.route('/communities/<int:community_id>', methods=['GET'])
@token_required
def get_community(community_id):
    """Get community details by ID"""
    try:
        community = community_service.get_community(community_id)
        
        if not community:
            return jsonify({"error": "Community not found"}), 404
        
        return jsonify({"community": community.to_dict()}), 200
        
    except Exception as e:
        return jsonify({"error": "Internal server error"}), 500


@community_bp.route('/communities/<int:community_id>', methods=['PUT'])
@token_required
def update_community(community_id):
    """Update community details (admin only)"""
    try:
        data = request.get_json()
        user_id = request.user_id
        
        # Update community
        community = community_service.update_community(
            community_id=community_id,
            user_id=user_id,
            name=data.get('name'),
            description=data.get('description'),
            privacy_id=data.get('privacy_id')
        )
        
        return jsonify({
            "message": "Community updated successfully",
            "community": community.to_dict()
        }), 200
        
    except ValueError as e:
        return jsonify({"error": str(e)}), 403
    except Exception as e:
        return jsonify({"error": "Internal server error"}), 500


@community_bp.route('/communities/<int:community_id>', methods=['DELETE'])
@token_required
def delete_community(community_id):
    """Delete a community (admin only)"""
    try:
        user_id = request.user_id
        
        success = community_service.delete_community(community_id, user_id)
        
        if success:
            return jsonify({"message": "Community deleted successfully"}), 200
        else:
            return jsonify({"error": "Failed to delete community"}), 500
        
    except ValueError as e:
        return jsonify({"error": str(e)}), 403
    except Exception as e:
        return jsonify({"error": "Internal server error"}), 500


@community_bp.route('/communities/<int:community_id>/join', methods=['POST'])
@token_required
def join_community(community_id):
    """Join a community as a member"""
    try:
        user_id = request.user_id
        
        member = community_service.join_community(community_id, user_id)
        
        return jsonify({
            "message": "Successfully joined community",
            "membership": member
        }), 201
        
    except ValueError as e:
        return jsonify({"error": str(e)}), 400
    except Exception as e:
        return jsonify({"error": "Internal server error"}), 500


@community_bp.route('/communities/<int:community_id>/leave', methods=['POST'])
@token_required
def leave_community(community_id):
    """Leave a community"""
    try:
        user_id = request.user_id
        
        success = community_service.leave_community(community_id, user_id)
        
        if success:
            return jsonify({"message": "Successfully left community"}), 200
        else:
            return jsonify({"error": "Failed to leave community"}), 500
        
    except ValueError as e:
        return jsonify({"error": str(e)}), 400
    except Exception as e:
        return jsonify({"error": "Internal server error"}), 500


@community_bp.route('/communities/<int:community_id>/members', methods=['GET'])
@token_required
def get_community_members(community_id):
    """Get all members of a community"""
    try:
        limit = request.args.get('limit', 50, type=int)
        offset = request.args.get('offset', 0, type=int)
        
        # Validate pagination parameters
        if limit < 1 or limit > 100:
            return jsonify({"error": "Limit must be between 1 and 100"}), 400
        if offset < 0:
            return jsonify({"error": "Offset must be non-negative"}), 400
        
        members = community_service.get_members(community_id, limit, offset)
        
        return jsonify({
            "members": members,
            "limit": limit,
            "offset": offset
        }), 200
        
    except ValueError as e:
        return jsonify({"error": str(e)}), 404
    except Exception as e:
        return jsonify({"error": "Internal server error"}), 500


@community_bp.route('/communities/<int:community_id>/members/<int:target_user_id>', methods=['DELETE'])
@token_required
def remove_community_member(community_id, target_user_id):
    """Remove a member from community (admin/moderator only)"""
    try:
        user_id = request.user_id
        
        success = community_service.remove_member(community_id, user_id, target_user_id)
        
        if success:
            return jsonify({"message": "Member removed successfully"}), 200
        else:
            return jsonify({"error": "Failed to remove member"}), 500
        
    except ValueError as e:
        return jsonify({"error": str(e)}), 403
    except Exception as e:
        return jsonify({"error": "Internal server error"}), 500


@community_bp.route('/communities/<int:community_id>/members/<int:target_user_id>/role', methods=['PUT'])
@token_required
def change_member_role(community_id, target_user_id):
    """Change a member's role (admin only)"""
    try:
        data = request.get_json()
        user_id = request.user_id
        
        # Validate role_id
        role_id = data.get('role_id')
        if not role_id:
            return jsonify({"error": "role_id is required"}), 400
        
        if not isinstance(role_id, int) or role_id not in [1, 2, 3]:
            return jsonify({"error": "role_id must be 1 (admin), 2 (moderator), or 3 (member)"}), 400
        
        member = community_service.change_member_role(community_id, user_id, target_user_id, role_id)
        
        return jsonify({
            "message": "Member role updated successfully",
            "membership": member
        }), 200
        
    except ValueError as e:
        return jsonify({"error": str(e)}), 403
    except Exception as e:
        return jsonify({"error": "Internal server error"}), 500


@community_bp.route('/me/communities', methods=['GET'])
@token_required
def get_my_communities():
    """Get all communities the authenticated user is a member of"""
    try:
        user_id = request.user_id
        
        communities = community_service.get_user_communities(user_id)
        
        return jsonify({"communities": communities}), 200
        
    except Exception as e:
        return jsonify({"error": "Internal server error"}), 500
