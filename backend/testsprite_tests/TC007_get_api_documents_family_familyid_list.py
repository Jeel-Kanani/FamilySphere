import requests
import uuid
import time
import json

BASE_URL = "http://localhost:5000"
TIMEOUT = 30

API_KEY = "806870586097-qlgq0fm3c03ink7khc8hfe1n52mig2tn.apps.googleusercontent.com"
TEST_OTP = "111111"


def register_user(email, password, name):
    url = f"{BASE_URL}/api/auth/register"
    headers = {"Content-Type": "application/json"}
    payload = {
        "email": email,
        "password": password,
        "name": name,
        "otp": TEST_OTP  # use test OTP environment variable for registration
    }
    resp = requests.post(url, json=payload, headers=headers, timeout=TIMEOUT)
    return resp


def login_user(email, password):
    url = f"{BASE_URL}/api/auth/login"
    headers = {"Content-Type": "application/json"}
    payload = {
        "email": email,
        "password": password
    }
    resp = requests.post(url, json=payload, headers=headers, timeout=TIMEOUT)
    return resp


def create_family(token, name, description, initial_members):
    url = f"{BASE_URL}/api/families"
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}"
    }
    payload = {
        "name": name,
        "description": description,
        "initialMembers": initial_members
    }
    resp = requests.post(url, json=payload, headers=headers, timeout=TIMEOUT)
    return resp


def upload_document(token, family_id, file_content, filename):
    url = f"{BASE_URL}/api/documents/upload"
    headers = {
        "Authorization": f"Bearer {token}"
    }
    files = {
        "file": (filename, file_content, "application/pdf")
    }
    metadata = {
        "familyId": family_id
    }
    # The API expects metadata as part of multipart/form-data, so send as another form part.
    # We'll serialize metadata as JSON string.
    multipart_data = {
        "metadata": (None, json.dumps(metadata), "application/json")
    }
    files.update(multipart_data)
    resp = requests.post(url, headers=headers, files=files, timeout=TIMEOUT)
    return resp


def get_family_documents(token, family_id):
    url = f"{BASE_URL}/api/documents/family/{family_id}"
    headers = {
        "Authorization": f"Bearer {token}"
    }
    resp = requests.get(url, headers=headers, timeout=TIMEOUT)
    return resp


def delete_family(token, family_id):
    # API does not specify delete family endpoint, so skipping.
    pass


def delete_document(token, document_id):
    # API does not specify delete document endpoint, so skipping.
    pass


def test_get_api_documents_family_familyid_list():
    # Generate unique user email for testing
    unique_id = str(uuid.uuid4())
    email = f"testuser_{unique_id}@example.com"
    password = "TestPassword123!"
    name = "Test User"

    # Register user (ignore conflict if user exists)
    try:
        resp_register = register_user(email, password, name)
        if resp_register.status_code != 201 and resp_register.status_code != 409:
            assert False, f"Registration failed with status {resp_register.status_code}: {resp_register.text}"
    except requests.RequestException as e:
        assert False, f"Registration request failed: {e}"

    # Login user to get JWT token
    try:
        resp_login = login_user(email, password)
        assert resp_login.status_code == 200, f"Login failed with status {resp_login.status_code}: {resp_login.text}"
        token = resp_login.json().get("token")
        assert token, "JWT token not found in login response"
    except requests.RequestException as e:
        assert False, f"Login request failed: {e}"

    # Create a family group with the user as initial member
    family_name = f"TestFamily_{unique_id}"
    family_description = "Family for testing documents"
    initial_members = []  # No other members, user will be default member

    try:
        resp_family = create_family(token, family_name, family_description, initial_members)
        assert resp_family.status_code == 201, f"Family creation failed with status {resp_family.status_code}: {resp_family.text}"
        family_id = resp_family.json().get("familyId")
        assert family_id, "familyId not found in family creation response"
    except requests.RequestException as e:
        assert False, f"Create family request failed: {e}"

    # Upload a sample document to the family to ensure there is at least one document
    document_id = None
    document_content = b"%PDF-1.4\n%Test PDF content\n%%EOF\n"
    document_filename = "testdoc.pdf"
    try:
        resp_upload = upload_document(token, family_id, document_content, document_filename)
        assert resp_upload.status_code == 201, f"Document upload failed with status {resp_upload.status_code}: {resp_upload.text}"
        document_id = resp_upload.json().get("documentId")
        assert document_id, "documentId not found in document upload response"
    except requests.RequestException as e:
        assert False, f"Document upload request failed: {e}"

    # Wait a few seconds for OCR processing (simulate wait)
    time.sleep(3)

    try:
        # Retrieve all documents for the family
        resp_docs = get_family_documents(token, family_id)
        assert resp_docs.status_code == 200, f"Get family documents failed with status {resp_docs.status_code}: {resp_docs.text}"
        docs = resp_docs.json()
        assert isinstance(docs, list), "Documents response is not a list"
        assert any(doc.get("documentId") == document_id for doc in docs), "Uploaded document not found in documents list"
        # Check OCR text presence (may be empty or string)
        for doc in docs:
            assert "documentId" in doc, "documentId missing in document entry"
            assert "familyId" in doc, "familyId missing in document entry"
            assert "userId" in doc, "userId missing in document entry"
            assert "ocrText" in doc, "ocrText missing in document entry"
    except requests.RequestException as e:
        assert False, f"Get documents request failed: {e}"

    # No explicit delete API for family or document noted in PRD; skipping resource cleanup.


test_get_api_documents_family_familyid_list()
