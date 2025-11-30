from functools import wraps
from flask import request, jsonify


def authorize(roles=None):
    """Rol bazlı yetkilendirme decorator'ı"""
    def decorator(f):
        @wraps(f)
        def decorated(*args, **kwargs):
            # Authorization logic will be implemented here
            pass
        return decorated
    return decorator
