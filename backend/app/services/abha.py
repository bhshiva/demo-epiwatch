"""
ABHA (Ayushman Bharat Health Account) validation and verification.

Two layers, deliberately separated:

  * ``validate_abha`` -- offline format and checksum check. Catches a mistyped
    number at the point of entry with no network call, and keeps working when
    ABDM is unreachable, which at a rural clinic is the normal case.
  * ``AbdmClient``    -- verification against the national registry, confirming
    the number exists and returning the demographics on file.

ABHA numbers carry a Verhoeff checksum (the same scheme Aadhaar uses), so a
single mistyped or transposed digit is detectable locally.
"""

from __future__ import annotations

import os
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone

import httpx

# Verhoeff dihedral group D5 multiplication table.
_D_TABLE = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
    [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
    [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
    [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
    [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
    [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
    [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
    [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
    [9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
]

# Permutation table applied per digit position.
_P_TABLE = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
    [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
    [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
    [9, 4, 5, 3, 1, 2, 6, 8, 7, 0],
    [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
    [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
    [7, 0, 4, 6, 9, 1, 3, 2, 5, 8],
]

ABHA_LENGTH = 14


def normalise_abha(value: str | None) -> str | None:
    """Digits only. ABHA is commonly written as 12-3456-7890-1234."""
    if not value:
        return None
    digits = "".join(ch for ch in value if ch.isdigit())
    return digits or None


def verhoeff_check(digits: str) -> bool:
    """True when the trailing Verhoeff check digit is consistent."""
    checksum = 0
    for position, digit in enumerate(reversed(digits)):
        checksum = _D_TABLE[checksum][_P_TABLE[position % 8][int(digit)]]
    return checksum == 0


@dataclass
class AbhaValidation:
    is_valid: bool
    normalised: str | None
    reason: str | None = None


def validate_abha(value: str | None) -> AbhaValidation:
    """
    Offline validation. Returns the reason on failure so the clinician is told
    what is wrong rather than simply refused.
    """
    normalised = normalise_abha(value)

    if not normalised:
        return AbhaValidation(False, None, "No ABHA number entered.")

    if len(normalised) != ABHA_LENGTH:
        return AbhaValidation(
            False,
            normalised,
            f"An ABHA number has {ABHA_LENGTH} digits; this has {len(normalised)}.",
        )

    if not verhoeff_check(normalised):
        return AbhaValidation(
            False,
            normalised,
            "This does not look like a valid ABHA number — check for a mistyped digit.",
        )

    return AbhaValidation(True, normalised)


@dataclass
class AbhaProfile:
    """Demographics as held by the national registry."""

    abha_number: str
    name: str | None = None
    gender: str | None = None
    date_of_birth: str | None = None
    mobile: str | None = None
    state_name: str | None = None
    district_name: str | None = None


class AbdmNotConfigured(RuntimeError):
    """Raised when ABDM credentials are absent, so callers can degrade cleanly."""


class AbdmUnavailable(RuntimeError):
    """ABDM could not be reached or refused the request."""


class AbdmClient:
    """
    Minimal ABDM v3 client covering session auth and ABHA verification.

    Base URLs are configuration, not constants, so the same code runs against
    the local mock, the NHA sandbox, and production without modification.
    """

    def __init__(
        self,
        *,
        base_url: str | None = None,
        gateway_url: str | None = None,
        client_id: str | None = None,
        client_secret: str | None = None,
        cm_id: str | None = None,
        timeout: float = 10.0,
    ):
        self.base_url = (base_url or os.getenv("ABDM_BASE_URL", "")).rstrip("/")
        self.gateway_url = (gateway_url or os.getenv("ABDM_GATEWAY_URL", "")).rstrip("/")
        self.client_id = client_id or os.getenv("ABDM_CLIENT_ID")
        self.client_secret = client_secret or os.getenv("ABDM_CLIENT_SECRET")
        # "sbx" for sandbox, "abdm" for production.
        self.cm_id = cm_id or os.getenv("ABDM_CM_ID", "sbx")
        self.timeout = timeout

    @property
    def is_configured(self) -> bool:
        return bool(self.base_url and self.gateway_url and self.client_id and self.client_secret)

    def _headers(self, token: str | None = None) -> dict[str, str]:
        headers = {
            "REQUEST-ID": str(uuid.uuid4()),
            "TIMESTAMP": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z"),
            "X-CM-ID": self.cm_id,
            "Content-Type": "application/json",
        }
        if token:
            headers["Authorization"] = f"Bearer {token}"
        return headers

    async def get_session_token(self) -> str:
        if not self.is_configured:
            raise AbdmNotConfigured(
                "ABDM credentials are not configured. Set ABDM_BASE_URL, "
                "ABDM_GATEWAY_URL, ABDM_CLIENT_ID and ABDM_CLIENT_SECRET."
            )

        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                resp = await client.post(
                    f"{self.gateway_url}/v3/sessions",
                    headers=self._headers(),
                    json={
                        "clientId": self.client_id,
                        "clientSecret": self.client_secret,
                        "grantType": "client_credentials",
                    },
                )
        except httpx.HTTPError as exc:
            raise AbdmUnavailable(f"Could not reach ABDM: {exc}") from exc

        if resp.status_code != 200:
            raise AbdmUnavailable(f"ABDM session request failed ({resp.status_code}).")

        token = resp.json().get("accessToken")
        if not token:
            raise AbdmUnavailable("ABDM session response contained no access token.")
        return token

    async def verify_abha(self, abha_number: str) -> AbhaProfile:
        """
        Confirm an ABHA exists and return its registered demographics.

        Validate offline first so an obviously wrong number never costs a
        round trip.
        """
        validation = validate_abha(abha_number)
        if not validation.is_valid:
            raise ValueError(validation.reason)

        normalised = validation.normalised
        token = await self.get_session_token()

        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                resp = await client.post(
                    f"{self.base_url}/v3/profile/account/abha-number",
                    headers=self._headers(token),
                    json={"abhaNumber": normalised},
                )
        except httpx.HTTPError as exc:
            raise AbdmUnavailable(f"Could not reach ABDM: {exc}") from exc

        if resp.status_code == 404:
            raise AbdmUnavailable("No ABHA account found for that number.")
        if resp.status_code != 200:
            raise AbdmUnavailable(f"ABDM verification failed ({resp.status_code}).")

        data = resp.json()
        return AbhaProfile(
            abha_number=normalised or "",
            name=data.get("name") or _join_name(data),
            gender=_expand_gender(data.get("gender")),
            date_of_birth=_join_dob(data),
            mobile=data.get("mobile"),
            state_name=data.get("stateName"),
            district_name=data.get("districtName"),
        )


def _join_name(data: dict) -> str | None:
    parts = [data.get("firstName"), data.get("middleName"), data.get("lastName")]
    joined = " ".join(p for p in parts if p)
    return joined or None


def _join_dob(data: dict) -> str | None:
    """ABDM returns date of birth split across three fields."""
    if data.get("dateOfBirth"):
        return data["dateOfBirth"]
    year, month, day = data.get("yearOfBirth"), data.get("monthOfBirth"), data.get("dayOfBirth")
    if year and month and day:
        return f"{int(year):04d}-{int(month):02d}-{int(day):02d}"
    return None


def _expand_gender(code: str | None) -> str | None:
    """ABDM uses single-letter codes; the app stores full words."""
    return {"M": "Male", "F": "Female", "O": "Other"}.get((code or "").upper()) or code or None
