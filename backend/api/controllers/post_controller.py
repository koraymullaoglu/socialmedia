from flask import Blueprint, request, jsonify
from api.services.post_service import PostService

post_bp = Blueprint('post', __name__)
post_service = PostService()


# Post controller endpoints will be implemented here
