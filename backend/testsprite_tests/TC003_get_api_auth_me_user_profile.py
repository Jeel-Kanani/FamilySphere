import requests
import uuid

BASE_URL = "http://localhost:5000"
TEST_EMAIL = f"testuser_{uuid.uuid4().hex[:8]}@example.com"
TEST_PASSWORD = "TestPass123!"
TEST_NAME = "Test User"
REGISTER_URL = f"{BASE_URL}/api/auth/register"
LOGIN_URL = f"{BASE_URL}/api/auth/login"
AUTH_ME_URL = f"{BASE_URL}/api/auth/me"
TIMEOUT = 30
HEADERS_JSON = {"Content-Type": "application/json"}


def test_get_api_auth_me_user_profile():
    # Register a new user using TEST_OTP environment variable (simulated via payload or backend dev mode)
    register_payload = {
        "email": TEST_EMAIL,
        "password": TEST_PASSWORD,
        "name": TEST_NAME,
        "otp": "111111"  # as per instructions: TEST_OTP environment variable value
    }

    # Attempt to register; if conflict (user exists), that's fine as per instructions
    try:
        resp = requests.post(REGISTER_URL, json=register_payload, timeout=TIMEOUT, headers=HEADERS_JSON)
        if resp.status_code not in (201, 409):
            resp.raise_for_status()
    except requests.HTTPError as e:
        if resp.status_code != 409:
            raise

    # Login to obtain JWT token
    login_payload = {
        "email": TEST_EMAIL,
        "password": TEST_PASSWORD
    }
    login_resp = requests.post(LOGIN_URL, json=login_payload, timeout=TIMEOUT, headers=HEADERS_JSON)
    assert login_resp.status_code == 200, f"Login failed with status {login_resp.status_code}: {login_resp.text}"
    login_data = login_resp.json()
    assert "token" in login_data and isinstance(login_data["token"], str) and login_data["token"], "JWT token missing in login response"
    token = login_data["token"]

    # Get current user profile
    headers_auth = {"Authorization": f"Bearer {token}"}
    profile_resp = requests.get(AUTH_ME_URL, timeout=TIMEOUT, headers=headers_auth)
    assert profile_resp.status_code == 200, f"Failed to get user profile: {profile_resp.status_code}, {profile_resp.text}"

    profile_data = profile_resp.json()
    # Verify required fields in response per instructions
    expected_fields = ["userId", "email", "name", "roles"]
    for field in expected_fields:
        assert field in profile_data, f"Missing field '{field}' in user profile response"

    # Additional basic validations
    assert profile_data["userId"], "userId should not be empty"
    # roles should be list and include at least one role
    assert isinstance(profile_data["roles"], list), "roles field should be a list"
    assert len(profile_data["roles"]) > 0, "roles list should not be empty"


test_get_api_auth_me_user_profile()
