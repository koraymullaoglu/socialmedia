from flask import Blueprint, request, jsonify, make_response, g
from api.services.follow_service import FollowService
from api.middleware.authorization import token_required

follow_bp = Blueprint('follow', __name__)
follow_service = FollowService()


@follow_bp.route('/users/<int:user_id>/follow', methods=['POST'])
@token_required
def follow_user(user_id):
    """Follow a user"""
    try:
        follower_id = g.current_user_id
        
        result = follow_service.follow_user(follower_id, user_id)
        
        if not result["success"]:
            return make_response(jsonify({"error": result["error"]}), 400)
        
        return make_response(jsonify(result), 201)
    
    except Exception as e:
        return make_response(jsonify({"error": str(e)}), 500)


@follow_bp.route('/users/<int:user_id>/follow', methods=['DELETE'])
@token_required
def unfollow_user(user_id):
    """Unfollow a user"""
    try:
        follower_id = g.current_user_id
        
        result = follow_service.unfollow_user(follower_id, user_id)
        
        if not result["success"]:
            return make_response(jsonify({"error": result["error"]}), 400)
        
        return make_response(jsonify(result), 200)
    
    except Exception as e:
        return make_response(jsonify({"error": str(e)}), 500)


@follow_bp.route('/users/<int:user_id>/followers', methods=['GET'])
@token_required
def get_followers(user_id):
    """Get followers of a user"""
    try:
        limit = request.args.get('limit', 100, type=int)
        offset = request.args.get('offset', 0, type=int)
        
        followers = follow_service.get_followers(user_id, limit, offset)
        
        return make_response(jsonify({
            "followers": followers,
            "count": len(followers)
        }), 200)
    
    except Exception as e:
        return make_response(jsonify({"error": str(e)}), 500)


@follow_bp.route('/users/<int:user_id>/following', methods=['GET'])
@token_required
def get_following(user_id):
    """Get users that a user is following"""
    try:
        limit = request.args.get('limit', 100, type=int)
        offset = request.args.get('offset', 0, type=int)
        
        following = follow_service.get_following(user_id, limit, offset)
        
        return make_response(jsonify({
            "following": following,
            "count": len(following)
        }), 200)
    
    except Exception as e:
        return make_response(jsonify({"error": str(e)}), 500)


@follow_bp.route('/me/follow-requests', methods=['GET'])
@token_required
def get_pending_requests():
    """Get pending follow requests for current user"""
    try:
        user_id = g.current_user_id
        limit = request.args.get('limit', 100, type=int)
        offset = request.args.get('offset', 0, type=int)
        
        requests = follow_service.get_pending_requests(user_id, limit, offset)
        
        return make_response(jsonify({
            "requests": requests,
            "count": len(requests)
        }), 200)
    
    except Exception as e:
        return make_response(jsonify({"error": str(e)}), 500)


@follow_bp.route('/me/follow-requests/<int:follower_id>/accept', methods=['POST'])
@token_required
def accept_follow_request(follower_id):
    """Accept a follow request"""
    try:
        following_id = g.current_user_id
        
        result = follow_service.accept_follow_request(follower_id, following_id)
        
        if not result["success"]:
            return make_response(jsonify({"error": result["error"]}), 400)
        
        return make_response(jsonify(result), 200)
    
    except Exception as e:
        return make_response(jsonify({"error": str(e)}), 500)


@follow_bp.route('/me/follow-requests/<int:follower_id>/reject', methods=['POST'])
@token_required
def reject_follow_request(follower_id):
    """Reject a follow request"""
    try:
        following_id = g.current_user_id
        
        result = follow_service.reject_follow_request(follower_id, following_id)
        
        if not result["success"]:
            return make_response(jsonify({"error": result["error"]}), 400)
        
        return make_response(jsonify(result), 200)
    
    except Exception as e:
        return make_response(jsonify({"error": str(e)}), 500)
