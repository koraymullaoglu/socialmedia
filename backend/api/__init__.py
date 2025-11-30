from flask import Flask
from flask_cors import CORS
from api.config import Config
from api.extensions import db


def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)
    
    CORS(app)
    
    # Initialize database
    db.init_app(app)
    
    # Register blueprints (import here to avoid circular imports)
    from api.controllers.api import api_bp
    app.register_blueprint(api_bp, url_prefix='/api')
    
    return app