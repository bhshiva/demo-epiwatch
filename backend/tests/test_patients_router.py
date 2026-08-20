import uuid

from fastapi.testclient import TestClient

from app.main import app
from scripts.seed import seed, SEED_DOCTOR_EMAIL, SEED_DOCTOR_PASSWORD

client = TestClient(app)


def _login_headers():
    seed()
    resp = client.post(
        "/auth/login",
        json={"email": SEED_DOCTOR_EMAIL, "password": SEED_DOCTOR_PASSWORD},
    )
    return {"Authorization": f"Bearer {resp.json()['access_token']}"}


def _register_patient(headers, name, mrn=None):
    """Create a report that registers a new named patient, return its patient_id."""
    payload = {
        "patient_identity": {"full_name": name, "exact_age": 40, "facility_mrn": mrn},
        "patient_exact_age": 40,
        "patient_age_group": "25-44",
        "patient_sex": "Male",
        "patient_district": "Pune",
        "report_date": "2026-08-18",
        "complaints": "Initial visit",
        # These helpers deliberately register distinct people, so acknowledge
        # the duplicate check rather than tripping over near-matches left by
        # earlier runs of the suite.
        "confirmed_new": True,
    }
    resp = client.post("/reports", json=payload, headers=headers)
    assert resp.status_code == 200

    found = client.get(f"/patients/search?q={name.split()[0]}", headers=headers).json()
    match = next(p for p in found if p["full_name"] == name)
    return match["patient_id"]


def test_search_requires_auth():
    assert client.get("/patients/search?q=a").status_code in (401, 403)


def test_history_requires_auth():
    resp = client.get(f"/patients/{uuid.uuid4()}/history")
    assert resp.status_code in (401, 403)


def test_registering_patient_makes_them_searchable():
    headers = _login_headers()
    name = f"Search Target {uuid.uuid4().hex[:6]}"

    _register_patient(headers, name)

    results = client.get(f"/patients/search?q={name.split()[0]}", headers=headers).json()
    assert any(p["full_name"] == name for p in results)


def test_reusing_patient_id_does_not_create_a_duplicate():
    """The whole point of the identity layer: one person, many reports."""
    headers = _login_headers()
    name = f"Repeat Visitor {uuid.uuid4().hex[:6]}"
    patient_id = _register_patient(headers, name)

    client.post(
        "/reports",
        json={
            "patient_id": patient_id,
            "patient_exact_age": 40,
            "patient_age_group": "25-44",
            "patient_sex": "Male",
            "patient_district": "Pune",
            "report_date": "2026-08-19",
            "complaints": "Follow-up visit",
        },
        headers=headers,
    )

    matches = [
        p
        for p in client.get(f"/patients/search?q={name.split()[0]}", headers=headers).json()
        if p["full_name"] == name
    ]

    assert len(matches) == 1, "a second visit must not create a second patient"
    assert matches[0]["report_count"] == 2


def test_history_returns_visits_newest_first():
    headers = _login_headers()
    name = f"History Case {uuid.uuid4().hex[:6]}"
    patient_id = _register_patient(headers, name)

    client.post(
        "/reports",
        json={
            "patient_id": patient_id,
            "patient_age_group": "25-44",
            "patient_sex": "Male",
            "patient_district": "Pune",
            "report_date": "2026-08-19",
            "complaints": "Later visit",
        },
        headers=headers,
    )

    history = client.get(f"/patients/{patient_id}/history", headers=headers).json()

    assert len(history) == 2
    assert history[0]["report_date"] >= history[1]["report_date"]


def test_history_404s_for_unknown_patient():
    headers = _login_headers()
    resp = client.get(f"/patients/{uuid.uuid4()}/history", headers=headers)
    assert resp.status_code == 404


def test_report_with_unknown_patient_id_is_rejected():
    headers = _login_headers()
    resp = client.post(
        "/reports",
        json={
            "patient_id": str(uuid.uuid4()),
            "patient_age_group": "25-44",
            "patient_sex": "Male",
            "patient_district": "Pune",
            "report_date": "2026-08-19",
            "complaints": "Ghost patient",
        },
        headers=headers,
    )
    assert resp.status_code == 404


def test_anonymous_patient_reports_still_work():
    """Reports without identity must keep working — identity is optional."""
    headers = _login_headers()
    resp = client.post(
        "/reports",
        json={
            "patient_age_group": "45-64",
            "patient_sex": "Female",
            "patient_district": "Mumbai",
            "report_date": "2026-08-19",
            "complaints": "Walk-in, no identity recorded",
        },
        headers=headers,
    )
    assert resp.status_code == 200


# --- duplicate detection ---


def test_match_requires_auth():
    resp = client.post("/patients/match", json={"full_name": "Anyone"})
    assert resp.status_code in (401, 403)


def test_match_finds_an_existing_patient_by_name():
    headers = _login_headers()
    name = f"Match Target {uuid.uuid4().hex[:6]}"
    _register_patient(headers, name)

    results = client.post(
        "/patients/match",
        json={"full_name": name, "exact_age": 40, "sex": "Male", "district": "Pune"},
        headers=headers,
    ).json()

    assert any(c["full_name"] == name for c in results)
    top = next(c for c in results if c["full_name"] == name)
    assert top["score"] >= 0.75
    assert top["matched_on"], "a warning with no explanation gets dismissed"


def test_match_ignores_a_clearly_different_person():
    """Over-blocking causes warning fatigue, which gets the feature switched off."""
    headers = _login_headers()
    _register_patient(headers, f"Distinct One {uuid.uuid4().hex[:6]}")

    results = client.post(
        "/patients/match",
        json={"full_name": "Zzyzx Quembersnoot", "exact_age": 90},
        headers=headers,
    ).json()

    assert results == []


def test_duplicate_registration_is_blocked_with_candidates():
    headers = _login_headers()
    name = f"Repeat Register {uuid.uuid4().hex[:6]}"
    _register_patient(headers, name)

    resp = client.post(
        "/reports",
        json={
            "patient_identity": {"full_name": name, "exact_age": 40},
            "patient_exact_age": 40,
            "patient_age_group": "25-44",
            "patient_sex": "Male",
            "patient_district": "Pune",
            "report_date": "2026-08-19",
            "complaints": "Second registration attempt",
        },
        headers=headers,
    )

    assert resp.status_code == 409
    detail = resp.json()["detail"]
    assert detail["reason"] == "possible_duplicate"
    assert detail["candidates"]


def test_confirmed_new_creates_a_genuinely_different_person():
    """Two real people can share a name; the clinician must be able to proceed."""
    headers = _login_headers()
    name = f"Same Name {uuid.uuid4().hex[:6]}"
    _register_patient(headers, name)

    resp = client.post(
        "/reports",
        json={
            "patient_identity": {"full_name": name, "exact_age": 70},
            "confirmed_new": True,
            "patient_exact_age": 70,
            "patient_age_group": "65+",
            "patient_sex": "Male",
            "patient_district": "Pune",
            "report_date": "2026-08-19",
            "complaints": "Different person, same name",
        },
        headers=headers,
    )
    assert resp.status_code == 200


def test_duplicate_mrn_returns_409_not_500():
    """This previously surfaced as an unhandled IntegrityError."""
    headers = _login_headers()
    mrn = f"MRN-{uuid.uuid4().hex[:8]}"
    _register_patient(headers, f"Mrn Holder {uuid.uuid4().hex[:6]}", mrn=mrn)

    resp = client.post(
        "/reports",
        json={
            "patient_identity": {"full_name": "Totally Unrelated Person", "facility_mrn": mrn},
            "confirmed_new": True,
            "patient_age_group": "25-44",
            "patient_sex": "Female",
            "patient_district": "Mumbai",
            "report_date": "2026-08-19",
            "complaints": "Reused MRN",
        },
        headers=headers,
    )
    assert resp.status_code == 409
    assert resp.json()["detail"]["reason"] == "exact_match"


def test_duplicate_abha_is_not_overridable():
    """A national ID collision is a fact, not a judgement call."""
    headers = _login_headers()
    abha = "".join(str((i * 7) % 10) for i in range(14))

    first = client.post(
        "/reports",
        json={
            "patient_identity": {"full_name": f"Abha One {uuid.uuid4().hex[:6]}", "abha_id": abha},
            "confirmed_new": True,
            "patient_age_group": "25-44",
            "patient_sex": "Male",
            "patient_district": "Pune",
            "report_date": "2026-08-19",
            "complaints": "First",
        },
        headers=headers,
    )
    # Tolerate a pre-existing row from an earlier run of this test.
    assert first.status_code in (200, 409)

    resp = client.post(
        "/reports",
        json={
            "patient_identity": {"full_name": "Someone Else Entirely", "abha_id": abha},
            "confirmed_new": True,
            "patient_age_group": "45-64",
            "patient_sex": "Female",
            "patient_district": "Mumbai",
            "report_date": "2026-08-19",
            "complaints": "Same ABHA",
        },
        headers=headers,
    )
    assert resp.status_code == 409
    assert resp.json()["detail"]["reason"] == "exact_match"


def test_anonymous_reports_bypass_duplicate_checking():
    """Reports with no identity have nobody to duplicate."""
    headers = _login_headers()
    for _ in range(2):
        resp = client.post(
            "/reports",
            json={
                "patient_age_group": "45-64",
                "patient_sex": "Female",
                "patient_district": "Mumbai",
                "report_date": "2026-08-19",
                "complaints": "Walk-in, no identity recorded",
            },
            headers=headers,
        )
        assert resp.status_code == 200


# --- ABHA verification ---

VALID_ABHA = "91234567890124"


def test_verify_abha_requires_auth():
    resp = client.post("/patients/verify-abha", json={"abha_number": VALID_ABHA})
    assert resp.status_code in (401, 403)


def test_verify_abha_rejects_a_mistyped_number():
    headers = _login_headers()
    broken = VALID_ABHA[:5] + str((int(VALID_ABHA[5]) + 1) % 10) + VALID_ABHA[6:]

    body = client.post(
        "/patients/verify-abha", json={"abha_number": broken}, headers=headers
    ).json()

    assert body["is_valid"] is False
    assert body["verified"] is False
    assert body["message"], "a refusal must say why"


def test_verify_abha_accepts_formatted_input():
    """Clinicians read ABHA numbers as 91-2345-6789-0124."""
    headers = _login_headers()

    body = client.post(
        "/patients/verify-abha",
        json={"abha_number": "91-2345-6789-0124"},
        headers=headers,
    ).json()

    assert body["is_valid"] is True
    assert body["abha_number"] == VALID_ABHA


def test_verify_abha_never_blocks_the_clinician_when_abdm_is_down():
    """
    ABDM being unreachable must degrade to the offline checksum result, not
    fail the request -- refusing to register a patient because a government
    API is down is worse than the problem it solves.
    """
    headers = _login_headers()

    resp = client.post(
        "/patients/verify-abha", json={"abha_number": VALID_ABHA}, headers=headers
    )

    assert resp.status_code == 200
    body = resp.json()
    assert body["is_valid"] is True
    # "verified" may be true or false depending on whether the mock gateway is
    # running; the contract is that the call always succeeds and reports which.
    assert isinstance(body["verified"], bool)
