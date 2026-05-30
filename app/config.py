import os

class Config:
    """Base configuration class with environment-based settings.
    
    AWS Elastic Beanstalk automatically injects RDS credentials as 
    RDS_USERNAME, RDS_PASSWORD, RDS_HOSTNAME, RDS_PORT, RDS_DB_NAME.
    """
    SECRET_KEY = os.environ.get('SECRET_KEY', 'dev-secret-key-change-in-production')
    FLASK_ENV = os.environ.get('FLASK_ENV', 'development')
    DEBUG = os.environ.get('FLASK_DEBUG', 'False').lower() in ('true', '1', 't')
    
    # AWS RDS default environment variables
    DB_USER = os.environ.get('RDS_USERNAME', 'db_user')
    DB_PASSWORD = os.environ.get('RDS_PASSWORD', 'db_password')
    DB_HOST = os.environ.get('RDS_HOSTNAME', 'localhost')
    DB_PORT = os.environ.get('RDS_PORT', '5432')
    DB_NAME = os.environ.get('RDS_DB_NAME', 'flask_app_db')
    
    # Database URI construction (uses RDS if available, falls back to SQLite)
    if os.environ.get('RDS_HOSTNAME'):
        SQLALCHEMY_DATABASE_URI = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    else:
        SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL', 'sqlite:///app.db')
        
    SQLALCHEMY_TRACK_MODIFICATIONS = False

class ProductionConfig(Config):
    """Production configuration overrides."""
    DEBUG = False
    
    @classmethod
    def init_app(cls, app):
        if cls.SECRET_KEY == 'dev-secret-key-change-in-production':
            app.logger.warning(
                "SECURITY WARNING: SECRET_KEY is using the default development key. "
                "Set the SECRET_KEY environment variable in your AWS Console / configuration."
            )

class DevelopmentConfig(Config):
    """Development configuration overrides."""
    DEBUG = True

class TestingConfig(Config):
    """Testing configuration overrides."""
    TESTING = True
    SQLALCHEMY_DATABASE_URI = 'sqlite:///:memory:'

# Configuration mapping
config_by_name = {
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'testing': TestingConfig,
    'default': DevelopmentConfig
}
