"""Unit tests for the matching score. No HTTP, no database."""

from datetime import date

from app.services.patient_matching import (
    MatchCriteria,
    confidence_for,
    normalise_contact,
    normalise_digits,
    score_candidate,
)


def _score(criteria, **candidate):
    defaults = dict(
        name_similarity=1.0,
        phonetic_match=False,
        candidate_dob=None,
        candidate_age=None,
        candidate_sex=None,
        candidate_contact=None,
        candidate_district=None,
    )
    defaults.update(candidate)
    return score_candidate(criteria, **defaults)


def test_identical_records_score_one():
    criteria = MatchCriteria(
        full_name="Ramesh Kumar",
        date_of_birth=date(1985, 3, 12),
        sex="Male",
        contact_number="9876543210",
        district="Pune",
    )
    score, matched = _score(
        criteria,
        candidate_dob=date(1985, 3, 12),
        candidate_sex="Male",
        candidate_contact="+91 98765 43210",
        candidate_district="Pune",
    )
    assert score == 1.0
    assert "name" in matched and "date of birth" in matched


def test_phonetic_match_lifts_a_misspelled_name():
    """
    Transliterated Indian names diverge in spelling far more than in sound;
    trigram similarity alone underrates a true match.
    """
    criteria = MatchCriteria(full_name="Krishnan")
    score, _ = _score(criteria, name_similarity=0.35, phonetic_match=True)
    assert score >= 0.85


def test_transposed_day_and_month_is_not_treated_as_a_different_person():
    criteria = MatchCriteria(full_name="A B", date_of_birth=date(1990, 4, 7))
    score, _ = _score(criteria, candidate_dob=date(1990, 7, 4))
    # Name 1.0 * 0.40 + DOB 0.6 * 0.30, renormalised over 0.70 of weight.
    assert 0.8 < score < 0.9


def test_absent_dob_is_not_a_penalty():
    """Weights renormalise over available signals, so silence is not evidence."""
    criteria = MatchCriteria(full_name="Asha Patil")
    score, _ = _score(criteria)
    assert score == 1.0


def test_age_substitutes_for_missing_dob():
    criteria = MatchCriteria(full_name="Asha Patil", exact_age=40)
    close, _ = _score(criteria, candidate_age=41)
    far, _ = _score(criteria, candidate_age=70)
    assert close > far
    assert far < 0.75


def test_a_different_person_scores_below_the_display_floor():
    criteria = MatchCriteria(
        full_name="Priya Venkatesan",
        date_of_birth=date(1974, 1, 1),
        sex="Female",
        district="Chennai",
    )
    score, _ = _score(
        criteria,
        name_similarity=0.12,
        candidate_dob=date(1990, 6, 6),
        candidate_sex="Male",
        candidate_district="Pune",
    )
    assert score < 0.60


def test_mismatched_sex_alone_does_not_veto_a_match():
    """Sex can be miskeyed; refusing a true match over one field defeats the point."""
    criteria = MatchCriteria(
        full_name="Sam Roy", date_of_birth=date(1980, 2, 2), sex="Male"
    )
    score, _ = _score(criteria, candidate_dob=date(1980, 2, 2), candidate_sex="Female")
    assert score >= 0.75


def test_confidence_bands():
    assert confidence_for(0.95) == "auto"
    assert confidence_for(0.80) == "review"
    assert confidence_for(0.65) == "weak"


def test_identifier_normalisation():
    assert normalise_digits("1111 2222 3333 44") == "11112222333344"
    assert normalise_digits("") is None
    # +91-prefixed and bare forms of one number must compare equal.
    assert normalise_contact("+91 98765 43210") == normalise_contact("9876543210")
