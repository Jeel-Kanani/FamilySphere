import requests
import uuid
import os

BASE_URL = "http://localhost:5000"
TIMEOUT = 30

def test_post_api_documents_upload_document():
    # Register a unique user
    register_url = f"{BASE_URL}/api/auth/register"
    email = f"testuser_{uuid.uuid4().hex[:8]}@example.com"
    password = "TestPass123!"
    name = "Test User"
    register_payload = {
        "email": email,
        "password": password,
        "name": name
    }
    # This environment uses TEST_OTP=111111 in backend dev mode; skipping OTP as no OTP endpoint given
    r = requests.post(register_url, json=register_payload, timeout=TIMEOUT)
    assert r.status_code in [201, 409], f"Unexpected register status: {r.status_code}, body: {r.text}"
    # If already exists, continue to login anyway

    # Login to get JWT token
    login_url = f"{BASE_URL}/api/auth/login"
    login_payload = {
        "email": email,
        "password": password
    }
    r = requests.post(login_url, json=login_payload, timeout=TIMEOUT)
    assert r.status_code == 200, f"Login failed: {r.status_code}, body: {r.text}"
    login_data = r.json()
    assert "token" in login_data, "No token in login response"
    token = login_data["token"]

    headers_auth = {"Authorization": f"Bearer {token}"}

    family_id = None
    document_id = None

    try:
        # Create a new family
        family_create_url = f"{BASE_URL}/api/families"
        family_payload = {
            "name": f"TestFamily_{uuid.uuid4().hex[:8]}",
            "description": "Family for document upload test",
            "initialMembers": []
        }
        r = requests.post(family_create_url, json=family_payload, headers=headers_auth, timeout=TIMEOUT)
        assert r.status_code == 201, f"Create family failed: {r.status_code}, body: {r.text}"
        family_resp = r.json()
        assert "familyId" in family_resp, "No familyId in create response"
        family_id = family_resp["familyId"]

        # Prepare file and metadata for upload
        upload_url = f"{BASE_URL}/api/documents/upload"
        # Create a simple text file content in memory
        file_content = b"Test document content for upload."
        file_tuple = ('file', ('testdoc.txt', file_content, 'text/plain'))
        metadata = {"familyId": family_id, "personalFlag": False}
        # Metadata as json string for multipart fields
        metadata_str = '{"familyId":"%s","personalFlag":false}' % family_id

        files = {
            "file": ('testdoc.txt', file_content, 'text/plain'),
            "metadata": (None, metadata_str, 'application/json')
        }

        r = requests.post(upload_url, headers=headers_auth, files=files, timeout=TIMEOUT)
        assert r.status_code == 201, f"Document upload failed: {r.status_code}, body: {r.text}"
        upload_resp = r.json()
        assert "documentId" in upload_resp, "No documentId in upload response"
        assert "processingStatus" in upload_resp, "No processingStatus in upload response"
        assert "userId" in upload_resp, "userId missing in upload response"
        assert "familyId" in upload_resp, "familyId missing in upload response"
        document_id = upload_resp["documentId"]
    finally:
        # Cleanup: Delete the uploaded document if created
        if document_id:
            try:
                delete_doc_url = f"{BASE_URL}/api/documents/{document_id}"
                requests.delete(delete_doc_url, headers=headers_auth, timeout=TIMEOUT)
            except Exception:
                pass
        # Cleanup: Delete the created family if created
        if family_id:
            try:
                delete_family_url = f"{BASE_URL}/api/families/{family_id}"
                requests.delete(delete_family_url, headers=headers_auth, timeout=TIMEOUT)
            except Exception:
                pass

test_post_api_documents_upload_document()
