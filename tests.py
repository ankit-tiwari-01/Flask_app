import unittest
from app import create_app

class FlaskAppTestCase(unittest.TestCase):
    def setUp(self):
        self.app = create_app()
        self.app.config['TESTING'] = True
        self.client = self.app.test_client()

    def test_index_page(self):
        """Test that the main dashboard page loads with a HTTP 200 status code."""
        response = self.client.get('/')
        self.assertEqual(response.status_code, 200)
        self.assertIn(b'Production-Grade Flask Template', response.data)
        self.assertIn(b'System Environment', response.data)

    def test_health_check(self):
        """Test the AWS Target Group compatible health endpoint."""
        response = self.client.get('/health')
        self.assertEqual(response.status_code, 200)
        json_data = response.get_json()
        self.assertEqual(json_data['status'], 'healthy')
        self.assertIn('timestamp', json_data)
        self.assertEqual(json_data['services']['database'], 'connected')

    def test_api_status(self):
        """Test the mock API status response."""
        response = self.client.get('/api/status')
        self.assertEqual(response.status_code, 200)
        json_data = response.get_json()
        self.assertEqual(json_data['app_name'], 'AWS Flask Template App')
        self.assertEqual(json_data['version'], '1.0.0')

if __name__ == '__main__':
    unittest.main()
