from api.extensions import db
from api.config import Config


def get_db():
    """SQLAlchemy db instance'ını döndürür"""
    return db


def get_db_session():
    """Database session'ını döndürür"""
    return db.session
