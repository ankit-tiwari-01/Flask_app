import os
from flask import Flask
from flask_cors import CORS
from app.config import config_by_name

def create_app():
    """Application factory function to initialize and configure the Flask app."""
    app = Flask(__name__)
    
    # Load configuration based on the environment setting
    env_name = os.environ.get('FLASK_ENV', 'development')
    config_class = config_by_name.get(env_name, config_by_name['default'])
    app.config.from_object(config_class)
    
    # Enable Cross-Origin Resource Sharing (CORS) - useful for modern web APIs
    CORS(app)
    
    # Initialize class-specific config settings (like logging checks)
    if hasattr(config_class, 'init_app'):
        config_class.init_app(app)
        
    # Import and register blueprints
    from app.routes import main_blueprint
    app.register_blueprint(main_blueprint)
    
    return app
