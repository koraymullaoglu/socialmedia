from flask import Blueprint, request, jsonify
from api.services.user_service import UserService

user_bp = Blueprint('user', __name__)
user_service = UserService()


# User controller endpoints will be implemented here
