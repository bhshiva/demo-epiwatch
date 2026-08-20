"""ABHA validation. Pure unit tests -- no network, no database."""

import pytest

from app.services.abha import (
    AbdmClient,
    _expand_gender,
    _join_dob,
    _join_name,
    normalise_abha,
    validate_abha,
    verhoeff_check,
)

# Both carry correct Verhoeff check digits.
VALID_ABHA = "91234567890124"
OTHER_VALID_ABHA = "12345678901230"


def test_valid_abha_passes_checksum():
    assert verhoeff_check(VALID_ABHA)
    assert validate_abha(VALID_ABHA).is_valid


def test_single_mistyped_digit_is_rejected():
    """The reason a checksum exists: one wrong keystroke must not slip through."""
    broken = VALID_ABHA[:5] + str((int(VALID_ABHA[5]) + 1) % 10) + VALID_ABHA[6:]
    assert not verhoeff_check(broken)
    assert not validate_abha(broken).is_valid


def test_transposed_digits_are_rejected():
    """Verhoeff catches adjacent transposition, which a simple sum would miss."""
    chars = list(VALID_ABHA)
    chars[3], chars[4] = chars[4], chars[3]
    assert not verhoeff_check("".join(chars))


def test_formatting_is_stripped_before_validation():
    """ABHA is commonly written 91-2345-6789-0124."""
    assert normalise_abha("91-2345-6789-0124") == VALID_ABHA
    assert validate_abha("91 2345 6789 0124").is_valid


def test_wrong_length_is_reported_with_the_actual_length():
    result = validate_abha("1234")
    assert not result.is_valid
    assert "14 digits" in result.reason
    assert "4" in result.reason


def test_empty_input_is_rejected_without_crashing():
    for value in (None, "", "   ", "abcd"):
        assert not validate_abha(value).is_valid


def test_failure_always_explains_itself():
    """A refusal with no reason leaves the clinician stuck."""
    for value in (None, "1234", "91234567890123"):
        assert validate_abha(value).reason


def test_client_reports_missing_configuration():
    client = AbdmClient(base_url="", gateway_url="", client_id=None, client_secret=None)
    assert not client.is_configured


def test_client_is_configured_when_all_settings_present():
    client = AbdmClient(
        base_url="http://x/abha/api",
        gateway_url="http://x/gateway",
        client_id="id",
        client_secret="secret",
    )
    assert client.is_configured


def test_gateway_headers_include_abdm_tracing_fields():
    """ABDM rejects calls without these."""
    client = AbdmClient(
        base_url="http://x", gateway_url="http://x", client_id="i", client_secret="s"
    )
    headers = client._headers("tok")
    assert {"REQUEST-ID", "TIMESTAMP", "X-CM-ID"} <= headers.keys()
    assert headers["Authorization"] == "Bearer tok"


@pytest.mark.asyncio
async def test_verification_rejects_a_bad_number_without_calling_abdm():
    """An obviously wrong number should never cost a round trip."""
    client = AbdmClient(
        base_url="http://127.0.0.1:1",  # would fail if actually called
        gateway_url="http://127.0.0.1:1",
        client_id="i",
        client_secret="s",
    )
    with pytest.raises(ValueError):
        await client.verify_abha("1234")


def test_abdm_response_parsing():
    """ABDM splits the name across fields and DOB across three integers."""
    data = {
        "firstName": "Asha",
        "middleName": "",
        "lastName": "Patil",
        "yearOfBirth": "1985",
        "monthOfBirth": "03",
        "dayOfBirth": "12",
    }
    assert _join_name(data) == "Asha Patil"
    assert _join_dob(data) == "1985-03-12"
    assert _expand_gender("F") == "Female"
    assert _expand_gender("M") == "Male"
    # An unknown code passes through rather than becoming None.
    assert _expand_gender("X") == "X"
