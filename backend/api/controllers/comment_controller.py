from flask import Blueprint, request, jsonify
from api.services.comment_service import CommentService

comment_bp = Blueprint('comment', __name__)
comment_service = CommentService()


# Comment controller endpoints will be implemented here
