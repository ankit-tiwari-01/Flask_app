import os
from dotenv import load_dotenv

# Load local environment variables from .env if present
load_dotenv()

from app import create_app

# AWS Elastic Beanstalk expects a WSGI callable named 'application' in 'application.py'
application = create_app()

if __name__ == '__main__':
    # Local development runner
    port = int(os.environ.get('PORT', 5000))
    # Safety feature: turn debug mode on/off based on FLASK_DEBUG env var
    debug = os.environ.get('FLASK_DEBUG', 'False').lower() in ('true', '1', 't')
    application.run(host='0.0.0.0', port=port, debug=debug)
