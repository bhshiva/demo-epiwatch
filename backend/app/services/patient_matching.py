"""
Patient matching for duplicate prevention.

Two tiers. A strong identifier (ABHA, facility MRN) is conclusive on its own.
Everything else is scored, because the fields available at a clinic counter --
a name heard and typed, an approximate age, sometimes a phone number -- are
individually unreliable but jointly informative.

Deliberately never merges automatically. A false merge writes one patient's
clinical data into another patient's record; that is a safety event and is far
harder to undo than a duplicate. The engine's job is to surface candidates to
a clinician, who decides.
"""

from dataclasses import dataclass, field
from datetime import date

from sqlalchemy import text
from sqlalchemy.orm import Session

# Score at or above which two records almost certainly describe one person.
AUTO_THRESHOLD = 0.92
# Score at or above which the clinician must look before creating a new record.
REVIEW_THRESHOLD = 0.75
# Score below which a candidate is not worth showing at all.
WEAK_THRESHOLD = 0.60

# Trigram floor for pulling candidates out of the database. Deliberately loose:
# recall matters here, and the weighted score below -- not the index -- decides.
CANDIDATE_SIMILARITY_FLOOR = 0.3
CANDIDATE_LIMIT = 50

# Weights are renormalised over the signals actually present on both records,
# so a patient with no date of birth on file is not penalised for the absence.
WEIGHT_NAME = 0.40
WEIGHT_DOB = 0.30
WEIGHT_CONTACT = 0.15
WEIGHT_SEX = 0.10
WEIGHT_DISTRICT = 0.05

# A phonetic match is strong evidence even when spelling diverges, which is
# common for names transliterated from Devanagari, Tamil and other scripts
# (Krishnan/Krishnun, Reddy/Reddi). Acts as a floor under trigram similarity.
PHONETIC_MATCH_SCORE = 0.85


@dataclass
class MatchCriteria:
    """What the clinician has typed so far about the person in front of them."""

    full_name: str
    date_of_birth: date | None = None
    exact_age: int | None = None
    sex: str | None = None
    contact_number: str | None = None
    facility_mrn: str | None = None
    abha_id: str | None = None
    district: str | None = None


@dataclass
class MatchCandidate:
    patient_id: str
    full_name: str
    exact_age: int | None
    age_group: str
    sex: str
    district: str
    facility_mrn: str | None
    abha_id: str | None
    report_count: int
    last_visit: date | None
    score: float
    confidence: str
    match_type: str
    matched_on: list[str] = field(default_factory=list)


def normalise_digits(value: str | None) -> str | None:
    """Strip everything but digits, for identifiers typed with spaces/hyphens."""
    if not value:
        return None
    digits = "".join(ch for ch in value if ch.isdigit())
    return digits or None


def normalise_contact(value: str | None) -> str | None:
    """Last 10 digits, so +91/0-prefixed forms of one number compare equal."""
    digits = normalise_digits(value)
    return digits[-10:] if digits and len(digits) >= 10 else digits


def confidence_for(score: float) -> str:
    if score >= AUTO_THRESHOLD:
        return "auto"
    if score >= REVIEW_THRESHOLD:
        return "review"
    return "weak"


def _score_dob(a: date | None, b: date | None) -> float | None:
    """None means the signal is unavailable, so it is excluded from weighting."""
    if a is None or b is None:
        return None
    if a == b:
        return 1.0
    # Day/month transposition is one of the most common data-entry errors and
    # should not look like a different person.
    if a.year == b.year and a.day == b.month and a.month == b.day:
        return 0.6
    if a.year == b.year:
        return 0.5
    return 0.0


def _score_age(a: int | None, b: int | None) -> float | None:
    """Fallback when neither record has a date of birth. Age drifts; DOB does not."""
    if a is None or b is None:
        return None
    gap = abs(a - b)
    if gap <= 1:
        return 1.0
    if gap <= 3:
        return 0.5
    return 0.0


def score_candidate(
    criteria: MatchCriteria,
    *,
    name_similarity: float,
    phonetic_match: bool,
    candidate_dob: date | None,
    candidate_age: int | None,
    candidate_sex: str | None,
    candidate_contact: str | None,
    candidate_district: str | None,
) -> tuple[float, list[str]]:
    """Weighted score plus the human-readable reasons behind it."""
    signals: list[tuple[float, float, str]] = []  # (weight, score, label)

    name_score = max(name_similarity, PHONETIC_MATCH_SCORE if phonetic_match else 0.0)
    signals.append((WEIGHT_NAME, name_score, "name"))

    dob_score = _score_dob(criteria.date_of_birth, candidate_dob)
    if dob_score is not None:
        signals.append((WEIGHT_DOB, dob_score, "date of birth"))
    else:
        age_score = _score_age(criteria.exact_age, candidate_age)
        if age_score is not None:
            signals.append((WEIGHT_DOB, age_score, "age"))

    contact_a = normalise_contact(criteria.contact_number)
    contact_b = normalise_contact(candidate_contact)
    if contact_a and contact_b:
        signals.append((WEIGHT_CONTACT, 1.0 if contact_a == contact_b else 0.0, "contact"))

    if criteria.sex and candidate_sex:
        # Never disqualifying on its own -- sex can be miskeyed, and refusing to
        # surface a true match over one wrong character defeats the purpose.
        equal = criteria.sex.strip().lower() == candidate_sex.strip().lower()
        signals.append((WEIGHT_SEX, 1.0 if equal else 0.0, "sex"))

    if criteria.district and candidate_district:
        equal = criteria.district.strip().lower() == candidate_district.strip().lower()
        signals.append((WEIGHT_DISTRICT, 1.0 if equal else 0.0, "district"))

    total_weight = sum(w for w, _, _ in signals)
    if total_weight == 0:
        return 0.0, []

    score = sum(w * sc for w, sc, _ in signals) / total_weight
    matched_on = [label for _, sc, label in signals if sc >= 0.6]
    return round(score, 4), matched_on


_CANDIDATE_SQL = text(
    """
    SELECT
        pi.patient_id,
        pi.full_name,
        pi.date_of_birth,
        pi.contact_number,
        pi.facility_mrn,
        pi.abha_id,
        p.exact_age,
        p.age_group,
        p.sex,
        p.district,
        similarity(lower(pi.full_name), lower(:name)) AS name_similarity,
        dmetaphone(pi.full_name) = dmetaphone(:name) AS phonetic_match,
        COALESCE(rs.report_count, 0) AS report_count,
        rs.last_visit
    FROM master.patient_identities pi
    JOIN master.patients p ON p.patient_id = pi.patient_id
    LEFT JOIN (
        SELECT patient_id,
               COUNT(report_id) AS report_count,
               MAX(report_date) AS last_visit
        FROM raw.patient_reports
        GROUP BY patient_id
    ) rs ON rs.patient_id = pi.patient_id
    WHERE pi.facility_id = :facility_id
      AND (
            similarity(lower(pi.full_name), lower(:name)) > :floor
         OR dmetaphone(pi.full_name) = dmetaphone(:name)
      )
    ORDER BY similarity(lower(pi.full_name), lower(:name)) DESC
    LIMIT :limit
    """
)

_EXACT_SQL = text(
    """
    SELECT
        pi.patient_id, pi.full_name, pi.facility_mrn, pi.abha_id,
        p.exact_age, p.age_group, p.sex, p.district,
        COALESCE(rs.report_count, 0) AS report_count, rs.last_visit
    FROM master.patient_identities pi
    JOIN master.patients p ON p.patient_id = pi.patient_id
    LEFT JOIN (
        SELECT patient_id, COUNT(report_id) AS report_count, MAX(report_date) AS last_visit
        FROM raw.patient_reports GROUP BY patient_id
    ) rs ON rs.patient_id = pi.patient_id
    WHERE pi.facility_id = :facility_id
      AND (
            (CAST(:abha_id AS text) IS NOT NULL AND pi.abha_id = CAST(:abha_id AS text))
         OR (CAST(:mrn AS text) IS NOT NULL
             AND lower(trim(pi.facility_mrn)) = lower(trim(CAST(:mrn AS text))))
      )
    LIMIT 5
    """
)


def find_candidates(
    db: Session, facility_id, criteria: MatchCriteria
) -> list[MatchCandidate]:
    """
    Candidate duplicates for this patient, best first.

    Always scoped to the caller's facility: identities at other facilities are
    not this clinician's to see, so they can be neither matched nor leaked.
    """
    abha = normalise_digits(criteria.abha_id)
    mrn = criteria.facility_mrn.strip() if criteria.facility_mrn else None

    # Tier 1 -- a strong identifier is conclusive; do not dilute it with scoring.
    if abha or mrn:
        rows = db.execute(
            _EXACT_SQL,
            {"facility_id": str(facility_id), "abha_id": abha, "mrn": mrn},
        ).mappings().all()
        if rows:
            return [
                MatchCandidate(
                    patient_id=str(r["patient_id"]),
                    full_name=r["full_name"],
                    exact_age=r["exact_age"],
                    age_group=r["age_group"],
                    sex=r["sex"],
                    district=r["district"],
                    facility_mrn=r["facility_mrn"],
                    abha_id=r["abha_id"],
                    report_count=r["report_count"],
                    last_visit=r["last_visit"],
                    score=1.0,
                    confidence="auto",
                    match_type="exact_abha" if abha and r["abha_id"] == abha else "exact_mrn",
                    matched_on=["ABHA number"] if abha and r["abha_id"] == abha else ["facility MRN"],
                )
                for r in rows
            ]

    if not criteria.full_name or not criteria.full_name.strip():
        return []

    rows = db.execute(
        _CANDIDATE_SQL,
        {
            "facility_id": str(facility_id),
            "name": criteria.full_name.strip(),
            "floor": CANDIDATE_SIMILARITY_FLOOR,
            "limit": CANDIDATE_LIMIT,
        },
    ).mappings().all()

    candidates: list[MatchCandidate] = []
    for r in rows:
        score, matched_on = score_candidate(
            criteria,
            name_similarity=float(r["name_similarity"] or 0.0),
            phonetic_match=bool(r["phonetic_match"]),
            candidate_dob=r["date_of_birth"],
            candidate_age=r["exact_age"],
            candidate_sex=r["sex"],
            candidate_contact=r["contact_number"],
            candidate_district=r["district"],
        )
        if score < WEAK_THRESHOLD:
            continue

        candidates.append(
            MatchCandidate(
                patient_id=str(r["patient_id"]),
                full_name=r["full_name"],
                exact_age=r["exact_age"],
                age_group=r["age_group"],
                sex=r["sex"],
                district=r["district"],
                facility_mrn=r["facility_mrn"],
                abha_id=r["abha_id"],
                report_count=r["report_count"],
                last_visit=r["last_visit"],
                score=score,
                confidence=confidence_for(score),
                match_type="probabilistic",
                matched_on=matched_on,
            )
        )

    candidates.sort(key=lambda c: c.score, reverse=True)
    return candidates


def blocking_candidates(candidates: list[MatchCandidate]) -> list[MatchCandidate]:
    """Those strong enough that creating a new record needs confirmation."""
    return [c for c in candidates if c.score >= REVIEW_THRESHOLD]
