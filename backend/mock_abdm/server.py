"""
Mock ABDM gateway implementing the v3 contract used by app.services.abha.

Exists because real ABDM sandbox credentials require National Health Authority
registration (2-4 week approval), and shipping an integration nobody has ever
watched run is how bugs reach a clinic. This mirrors the documented request and
response shapes so the whole verification path -- session token, headers,
demographics parsing, error handling -- is exercised end to end today.

Run:  uvicorn mock_abdm.server:app --port 8010

Swap ABDM_BASE_URL / ABDM_GATEWAY_URL to the NHA sandbox when credentials
arrive; no application code changes.
"""

from datetime import datetime, timezone

from fastapi import FastAPI, Header, HTTPException, Request
from pydantic import BaseModel

app = FastAPI(title="Mock ABDM Gateway")

# Whatever the app is configured with is accepted; this stands in for NHA-issued
# credentials, which cannot be obtained without organisational registration.
VALID_CLIENT_ID = "mock-client-id"
VALID_CLIENT_SECRET = "mock-client-secret"
ISSUED_TOKEN = "mock-session-token-abcdef123456"

# Seeded accounts. Numbers carry correct Verhoeff check digits so they pass the
# app's offline validation before ever reaching this server.
ACCOUNTS: dict[str, dict] = {
    "91234567890124": {
        "firstName": "Rohan",
        "middleName": "",
        "lastName": "Deshmukh",
        "gender": "M",
        "yearOfBirth": "1992",
        "monthOfBirth": "04",
        "dayOfBirth": "17",
        "mobile": "9876543210",
        "stateName": "Maharashtra",
        "districtName": "Pune",
    },
    "12345678901230": {
        "firstName": "Asha",
        "middleName": "",
        "lastName": "Patil",
        "gender": "F",
        "yearOfBirth": "1985",
        "monthOfBirth": "03",
        "dayOfBirth": "12",
        "mobile": "9812345678",
        "stateName": "Maharashtra",
        "districtName": "Mumbai",
    },
}


class SessionRequest(BaseModel):
    clientId: str
    clientSecret: str
    grantType: str = "client_credentials"


class AbhaNumberRequest(BaseModel):
    abhaNumber: str


def _require_gateway_headers(request: Request) -> None:
    """ABDM rejects calls missing its tracing headers; the mock does too."""
    missing = [h for h in ("REQUEST-ID", "TIMESTAMP", "X-CM-ID") if h not in request.headers]
    if missing:
        raise HTTPException(status_code=400, detail=f"Missing headers: {', '.join(missing)}")


@app.post("/gateway/v3/sessions")
def create_session(body: SessionRequest, request: Request):
    _require_gateway_headers(request)

    if body.clientId != VALID_CLIENT_ID or body.clientSecret != VALID_CLIENT_SECRET:
        raise HTTPException(status_code=401, detail="Invalid client credentials")

    return {
        "accessToken": ISSUED_TOKEN,
        "expiresIn": 1800,
        "refreshExpiresIn": 1800,
        "tokenType": "bearer",
    }


@app.post("/abha/api/v3/profile/account/abha-number")
def verify_abha_number(
    body: AbhaNumberRequest,
    request: Request,
    authorization: str | None = Header(default=None),
):
    _require_gateway_headers(request)

    if authorization != f"Bearer {ISSUED_TOKEN}":
        raise HTTPException(status_code=401, detail="Invalid or missing session token")

    digits = "".join(ch for ch in body.abhaNumber if ch.isdigit())
    account = ACCOUNTS.get(digits)
    if account is None:
        raise HTTPException(status_code=404, detail="ABHA account not found")

    return {"abhaNumber": digits, **account}


@app.get("/health")
def health():
    return {"status": "ok", "service": "mock-abdm", "time": datetime.now(timezone.utc).isoformat()}
