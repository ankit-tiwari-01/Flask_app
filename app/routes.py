import os
import platform
from datetime import datetime, timezone
from flask import Blueprint, render_template, jsonify, current_app

main_blueprint = Blueprint('main', __name__)

@main_blueprint.route('/')
def index():
    """Renders the main dashboard/landing page."""
    context = {
        'os_name': platform.system(),
        'os_release': platform.release(),
        'python_version': platform.python_version(),
        'env': os.environ.get('FLASK_ENV', 'development'),
        'server_time': datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC"),
        'database_uri_type': 'RDS / PostgreSQL' if os.environ.get('RDS_HOSTNAME') else 'SQLite (Local)'
    }
    return render_template('index.html', **context)

@main_blueprint.route('/health')
def health_check():
    """AWS Load Balancer/ECS Health Check endpoint.
    
    Must return HTTP 200 for the instance to be marked as healthy.
    """
    health_status = {
        'status': 'healthy',
        'timestamp': datetime.now(timezone.utc).isoformat(),
        'services': {
            'database': 'connected' if check_database_connectivity() else 'disconnected',
            'disk_space': 'ok'
        }
    }
    return jsonify(health_status), 200

@main_blueprint.route('/api/status')
def api_status():
    """Mock API endpoint returning status info."""
    return jsonify({
        'app_name': 'AWS Flask Template App',
        'version': '1.0.0',
        'environment': os.environ.get('FLASK_ENV', 'development'),
        'debug_mode': current_app.config['DEBUG'],
        'time': datetime.now(timezone.utc).isoformat()
    })

def check_database_connectivity():
    """Check database connection.
    
    Replace this with real database checks (e.g., db.session.execute('SELECT 1'))
    when integrating ORM frameworks like SQLAlchemy.
    """
    return True
