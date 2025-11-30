from flask import Blueprint, request, jsonify
from api.services.community_service import CommunityService

community_bp = Blueprint('community', __name__)
community_service = CommunityService()


# Community controller endpoints will be implemented here
