import requests
import uuid

BASE_URL = "http://localhost:5000"
TIMEOUT = 30

def test_tc005_get_api_families_familyid_details():
    session = requests.Session()

    # Use TEST_OTP environment variable '111111' for registration in dev mode
    email = f"testuser_{uuid.uuid4().hex[:8]}@example.com"
    password = "TestPass123!"
    name = "Test User"

    headers = {"Content-Type": "application/json"}

    # Register user (if already exists, 409 Conflict is acceptable)
    try:
        reg_resp = session.post(
            f"{BASE_URL}/api/auth/register",
            json={
                "email": email,
                "password": password,
                "name": name,
                "otp": "111111"  # Include OTP for dev mode registration
            },
            headers=headers,
            timeout=TIMEOUT
        )
        if reg_resp.status_code not in (201, 409):
            assert False, f"Registration failed with status {reg_resp.status_code}: {reg_resp.text}"
    except requests.RequestException as e:
        assert False, f"Registration request failed: {e}"

    # Login user
    try:
        login_resp = session.post(
            f"{BASE_URL}/api/auth/login",
            json={"email": email, "password": password},
            headers=headers,
            timeout=TIMEOUT
        )
        assert login_resp.status_code == 200, f"Login failed: {login_resp.status_code} {login_resp.text}"
        login_json = login_resp.json()
        jwt_token = login_json.get("token") or login_json.get("jwt") or login_json.get("accessToken")
        assert jwt_token and isinstance(jwt_token, str), "JWT token not found in login response"
    except requests.RequestException as e:
        assert False, f"Login request failed: {e}"

    auth_headers = {"Authorization": f"Bearer {jwt_token}", "Content-Type": "application/json"}

    family_id = None

    # Create a family to get valid familyId
    try:
        family_payload = {
            "name": f"Test Family {uuid.uuid4().hex[:6]}",
            "description": "Family created for TC005",
            "initialMembers": []
        }
        family_resp = session.post(
            f"{BASE_URL}/api/families",
            json=family_payload,
            headers=auth_headers,
            timeout=TIMEOUT
        )
        assert family_resp.status_code == 201, f"Family creation failed: {family_resp.status_code} {family_resp.text}"
        family_resp_json = family_resp.json()
        family_id = family_resp_json.get("familyId")
        assert family_id and isinstance(family_id, str), "familyId not found in family creation response"
    except requests.RequestException as e:
        assert False, f"Family creation request failed: {e}"

    assert family_id is not None, "Family ID must be set for subsequent get"

    try:
        # GET family details with familyId
        get_family_resp = session.get(
            f"{BASE_URL}/api/families/{family_id}",
            headers=auth_headers,
            timeout=TIMEOUT
        )
        assert get_family_resp.status_code == 200, f"Get family details failed: {get_family_resp.status_code} {get_family_resp.text}"
        family_details = get_family_resp.json()

        # Validate presence of required standardized fields
        assert "familyId" in family_details, "'familyId' missing in response"
        assert family_details["familyId"] == family_id, "'familyId' in response does not match requested familyId"
        assert "members" in family_details and isinstance(family_details["members"], list), "'members' list missing or incorrect"
        # Check each member for userId field
        for member in family_details["members"]:
            assert "userId" in member, "Member entry missing 'userId' field"
            assert isinstance(member["userId"], str) and member["userId"], "'userId' field invalid in member"
    finally:
        # Cleanup: delete the created family
        try:
            del_resp = session.delete(
                f"{BASE_URL}/api/families/{family_id}",
                headers=auth_headers,
                timeout=TIMEOUT
            )
            # Deletion might not be implemented or return 204/200/404; ignore error here
        except requests.RequestException:
            pass


test_tc005_get_api_families_familyid_details()