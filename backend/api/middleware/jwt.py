from functools import wraps
from flask import request, jsonify


def token_required(f):
    """JWT token doğrulama decorator'ı"""
    @wraps(f)
    def decorated(*args, **kwargs):
        # JWT validation will be implemented here
        pass
    return decorated
