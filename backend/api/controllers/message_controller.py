from flask import Blueprint, request, jsonify, make_response, g
from api.services.message_service import MessageService
from api.middleware.authorization import token_required

message_bp = Blueprint('message', __name__)
message_service = MessageService()


@message_bp.route('/messages', methods=['POST'])
@token_required
def send_message():
    """Send a message to another user"""
    try:
        data = request.get_json()
        sender_id = g.current_user_id
        receiver_id = data.get("receiver_id")
        content = data.get("content")
        media_url = data.get("media_url")
        
        if not receiver_id:
            return make_response(jsonify({"error": "Receiver ID is required"}), 400)
        
        result = message_service.send_message(sender_id, receiver_id, content, media_url)
        
        if not result["success"]:
            return make_response(jsonify({"error": result["error"]}), 400)
        
        return make_response(jsonify(result), 201)
    
    except Exception as e:
        return make_response(jsonify({"error": str(e)}), 500)


@message_bp.route('/messages/conversations', methods=['GET'])
@token_required
def get_conversations():
    """Get all conversations for current user"""
    try:
        user_id = g.current_user_id
        limit = request.args.get('limit', 50, type=int)
        offset = request.args.get('offset', 0, type=int)
        
        conversations = message_service.get_conversations(user_id, limit, offset)
        
        return make_response(jsonify({
            "conversations": conversations,
            "count": len(conversations)
        }), 200)
    
    except Exception as e:
        return make_response(jsonify({"error": str(e)}), 500)


@message_bp.route('/messages/conversations/<int:other_user_id>', methods=['GET'])
@token_required
def get_conversation(other_user_id):
    """Get conversation with a specific user"""
    try:
        user_id = g.current_user_id
        limit = request.args.get('limit', 50, type=int)
        offset = request.args.get('offset', 0, type=int)
        
        result = message_service.get_conversation(user_id, other_user_id, limit, offset)
        
        if not result["success"]:
            return make_response(jsonify({"error": result["error"]}), 400)
        
        return make_response(jsonify(result), 200)
    
    except Exception as e:
        return make_response(jsonify({"error": str(e)}), 500)


@message_bp.route('/messages/<int:message_id>/read', methods=['PUT'])
@token_required
def mark_message_as_read(message_id):
    """Mark a message as read"""
    try:
        user_id = g.current_user_id
        
        result = message_service.mark_as_read(message_id, user_id)
        
        if not result["success"]:
            return make_response(jsonify({"error": result["error"]}), 400)
        
        return make_response(jsonify(result), 200)
    
    except Exception as e:
        return make_response(jsonify({"error": str(e)}), 500)


@message_bp.route('/messages/<int:message_id>', methods=['DELETE'])
@token_required
def delete_message(message_id):
    """Delete a message"""
    try:
        user_id = g.current_user_id
        
        result = message_service.delete_message(message_id, user_id)
        
        if not result["success"]:
            return make_response(jsonify({"error": result["error"]}), 400)
        
        return make_response(jsonify(result), 200)
    
    except Exception as e:
        return make_response(jsonify({"error": str(e)}), 500)


@message_bp.route('/messages/unread-count', methods=['GET'])
@token_required
def get_unread_count():
    """Get count of unread messages for current user"""
    try:
        user_id = g.current_user_id
        
        result = message_service.get_unread_count(user_id)
        
        return make_response(jsonify(result), 200)
    
    except Exception as e:
        return make_response(jsonify({"error": str(e)}), 500)
