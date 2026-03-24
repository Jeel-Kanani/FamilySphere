import requests

BASE_URL = "http://localhost:5000"
TIMEOUT = 30

def test_post_api_auth_login_user():
    login_url = f"{BASE_URL}/api/auth/login"
    # Using credentials that must be valid in the test environment
    payload = {
        "email": "testuser@example.com",
        "password": "TestPassword123"
    }
    headers = {
        "Content-Type": "application/json"
    }

    try:
        response = requests.post(login_url, json=payload, headers=headers, timeout=TIMEOUT)
    except requests.RequestException as e:
        assert False, f"Request to login endpoint failed: {e}"

    assert response.status_code == 200, f"Expected 200 OK, got {response.status_code}"
    json_data = response.json()
    # Check presence and type of JWT token
    assert "token" in json_data and isinstance(json_data["token"], str) and json_data["token"], "JWT token missing or invalid"

test_post_api_auth_login_user()