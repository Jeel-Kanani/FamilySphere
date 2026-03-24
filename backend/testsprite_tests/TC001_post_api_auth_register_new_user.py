import requests
import uuid

BASE_URL = "http://localhost:5000"
TIMEOUT = 30

def test_post_api_auth_register_new_user():
    url = f"{BASE_URL}/api/auth/register"
    unique_email = f"testuser_{uuid.uuid4().hex}@example.com"
    payload = {
        "email": unique_email,
        "password": "StrongPassword123!",
        "name": "Test User"
    }
    headers = {
        "Content-Type": "application/json"
    }
    try:
        response = requests.post(url, json=payload, headers=headers, timeout=TIMEOUT)
        assert response.status_code in (201, 409), f"Unexpected status code: {response.status_code}"
        json_resp = response.json()
        if response.status_code == 201:
            # New user created
            assert "userId" in json_resp, "userId not in response"
        else:
            # 409 Conflict if user already exists: error message expected
            assert "error" in json_resp and isinstance(json_resp["error"], str), "Expected error message for 409"
    except requests.RequestException as e:
        assert False, f"Request failed: {e}"

test_post_api_auth_register_new_user()
