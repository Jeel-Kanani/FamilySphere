import requests
import uuid

BASE_URL = "http://localhost:5000"
TIMEOUT = 30

API_KEY = "806870586097-qlgq0fm3c03ink7khc8hfe1n52mig2tn.apps.googleusercontent.com"


def test_post_api_families_create_family():
    # Register a new user (ignore if exists)
    email = f"testuser_{uuid.uuid4().hex[:8]}@example.com"
    password = "TestPass123!"
    name = "Test User"

    register_payload = {
        "email": email,
        "password": password,
        "name": name,
        "otp": "111111"  # Use TEST_OTP for registration in dev mode
    }

    try:
        reg_resp = requests.post(
            f"{BASE_URL}/api/auth/register",
            json=register_payload,
            timeout=TIMEOUT
        )
    except requests.RequestException as e:
        assert False, f"Registration request failed: {e}"

    # If conflict, user exists - proceed login, else expect 201 Created
    if reg_resp.status_code != 201:
        assert reg_resp.status_code == 409, f"Unexpected registration status: {reg_resp.status_code} {reg_resp.text}"

    # Login user to get JWT token
    login_payload = {
        "email": email,
        "password": password
    }

    try:
        login_resp = requests.post(
            f"{BASE_URL}/api/auth/login",
            json=login_payload,
            timeout=TIMEOUT
        )
    except requests.RequestException as e:
        assert False, f"Login request failed: {e}"

    assert login_resp.status_code == 200, f"Login failed: {login_resp.status_code} {login_resp.text}"
    login_json = login_resp.json()
    assert "token" in login_json, "Login response missing token"
    jwt_token = login_json["token"]

    headers_auth = {"Authorization": f"Bearer {jwt_token}"}

    family_payload = {
        "name": "Test Family " + uuid.uuid4().hex[:8],
        "description": "Test family description",
        "initialMembers": []
    }

    family_id = None
    try:
        # Create family
        try:
            family_resp = requests.post(
                f"{BASE_URL}/api/families",
                json=family_payload,
                headers=headers_auth,
                timeout=TIMEOUT
            )
        except requests.RequestException as e:
            assert False, f"Family creation request failed: {e}"

        assert family_resp.status_code == 201, f"Family creation failed: {family_resp.status_code} {family_resp.text}"
        family_json = family_resp.json()
        assert "familyId" in family_json, "Response missing familyId"

        family_id = family_json["familyId"]
        assert isinstance(family_id, str) and len(family_id) > 0, "familyId is empty or invalid"

    finally:
        # Cleanup: delete created family if possible
        if family_id:
            try:
                del_resp = requests.delete(
                    f"{BASE_URL}/api/families/{family_id}",
                    headers=headers_auth,
                    timeout=TIMEOUT
                )
                # Accept 204 No Content or 200 OK or 404 Not Found (if already deleted)
                assert del_resp.status_code in (200, 204, 404), f"Unexpected delete status: {del_resp.status_code}"
            except requests.RequestException:
                pass


test_post_api_families_create_family()