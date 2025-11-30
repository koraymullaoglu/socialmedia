from flask import Blueprint, request, jsonify
from api.services.message_service import MessageService

message_bp = Blueprint('message', __name__)
message_service = MessageService()


# Message controller endpoints will be implemented here
