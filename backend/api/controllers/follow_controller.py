from flask import Blueprint, request, jsonify
from api.services.follow_service import FollowService

follow_bp = Blueprint('follow', __name__)
follow_service = FollowService()


# Follow controller endpoints will be implemented here
