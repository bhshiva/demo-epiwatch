"""
Isolate + AST panel data model.

The shape being tested is the point of the migration: one organism carries a
panel of many antibiotic results, which raw.lab_results could not represent.
"""

import uuid

import pytest
from sqlalchemy import inspect, text
from sqlalchemy.exc import IntegrityError

from app.db import SessionLocal, engine
from app.models import AstResult, LabIsolate


@pytest.fixture
def db():
    session = SessionLocal()
    try:
        yield session
    finally:
        session.rollback()
        session.close()


@pytest.fixture
def facility_id(db):
    return db.execute(text("SELECT facility_id FROM master.facilities LIMIT 1")).scalar()


def test_orm_matches_the_database(db):
    """A drifted model surfaces as a confusing runtime error, so check up front."""
    insp = inspect(engine)
    for table, model in (("lab_isolates", LabIsolate), ("ast_results", AstResult)):
        db_cols = {c["name"] for c in insp.get_columns(table, schema="raw")}
        orm_cols = {c.name for c in model.__table__.columns}
        assert orm_cols == db_cols, f"{table}: {orm_cols ^ db_cols}"


def test_backfill_preserved_every_legacy_result(db):
    """Migration 007 must not lose anything already recorded."""
    legacy = db.execute(text("SELECT count(*) FROM raw.lab_results")).scalar()
    isolates = db.execute(text("SELECT count(*) FROM raw.lab_isolates")).scalar()
    legacy_with_drug = db.execute(
        text("SELECT count(*) FROM raw.lab_results WHERE antibiotic IS NOT NULL")
    ).scalar()
    ast_rows = db.execute(text("SELECT count(*) FROM raw.ast_results")).scalar()

    assert isolates >= legacy
    assert ast_rows >= legacy_with_drug


def test_one_isolate_carries_a_full_panel(db, facility_id):
    """The whole reason for the new shape: 12 drugs against one organism."""
    isolate = LabIsolate(
        facility_id=facility_id,
        pathogen="Escherichia coli",
        specimen_type="Urine",
        status="final",
    )
    drugs = [
        "Ciprofloxacin", "Ceftriaxone", "Meropenem", "Gentamicin",
        "Amikacin", "Cefixime", "Amoxicillin-Clavulanate", "Co-trimoxazole",
        "Nitrofurantoin", "Piperacillin-Tazobactam", "Ertapenem", "Levofloxacin",
    ]
    for drug in drugs:
        isolate.ast_results.append(AstResult(antibiotic=drug, ast_result="Susceptible"))

    db.add(isolate)
    db.flush()

    reloaded = db.get(LabIsolate, isolate.isolate_id)
    assert len(reloaded.ast_results) == 12


def test_same_drug_twice_on_one_isolate_is_rejected(db, facility_id):
    """A repeat result is an amendment, not a second row."""
    isolate = LabIsolate(facility_id=facility_id, pathogen="Klebsiella pneumoniae")
    isolate.ast_results.append(AstResult(antibiotic="Meropenem", ast_result="Resistant"))
    isolate.ast_results.append(AstResult(antibiotic="Meropenem", ast_result="Susceptible"))

    db.add(isolate)
    with pytest.raises(IntegrityError):
        db.flush()


def test_deleting_an_isolate_removes_its_panel(db, facility_id):
    """Orphaned AST rows would silently skew every resistance rate."""
    isolate = LabIsolate(facility_id=facility_id, pathogen="Staphylococcus aureus")
    isolate.ast_results.append(AstResult(antibiotic="Vancomycin", ast_result="Susceptible"))
    db.add(isolate)
    db.flush()

    isolate_id = isolate.isolate_id
    db.delete(isolate)
    db.flush()

    remaining = db.execute(
        text("SELECT count(*) FROM raw.ast_results WHERE isolate_id = :i"),
        {"i": isolate_id},
    ).scalar()
    assert remaining == 0


def test_isolate_can_exist_without_a_doctor_report(db, facility_id):
    """
    A laboratory receives a specimen and reports on it whether or not a
    clinician has filed anything. Requiring report_id is what blocked labs
    from submitting independently.
    """
    isolate = LabIsolate(
        facility_id=facility_id,
        pathogen="Acinetobacter baumannii",
        status="pending",
        report_id=None,
        patient_id=None,
    )
    db.add(isolate)
    db.flush()

    assert isolate.isolate_id is not None
    assert isolate.report_id is None


def test_status_is_constrained(db, facility_id):
    """Free-text status would make the worklist query meaningless."""
    db.add(LabIsolate(facility_id=facility_id, pathogen="X", status="not-a-real-status"))
    with pytest.raises(IntegrityError):
        db.flush()


def test_amendment_links_back_to_what_it_replaced(db, facility_id):
    """An overwritten result a clinician prescribed against must stay reconstructible."""
    original = LabIsolate(facility_id=facility_id, pathogen="Escherichia coli", status="final")
    db.add(original)
    db.flush()

    corrected = LabIsolate(
        facility_id=facility_id,
        pathogen="Escherichia coli",
        status="final",
        amended_from=original.isolate_id,
    )
    original.status = "amended"
    db.add(corrected)
    db.flush()

    assert corrected.amended_from == original.isolate_id
    assert original.status == "amended"


def test_mic_measurement_is_retained_alongside_the_interpretation(db, facility_id):
    """
    Storing only S/I/R discards the quantitative signal that makes MIC creep
    visible while the categorical call still reads "Susceptible".
    """
    isolate = LabIsolate(facility_id=facility_id, pathogen="Escherichia coli")
    isolate.ast_results.append(
        AstResult(
            antibiotic="Meropenem",
            ast_result="Susceptible",
            mic_value=0.5,
            mic_operator="<=",
            method="Broth microdilution",
        )
    )
    db.add(isolate)
    db.flush()

    ast = db.get(LabIsolate, isolate.isolate_id).ast_results[0]
    assert float(ast.mic_value) == 0.5
    assert ast.mic_operator == "<="
    assert ast.breakpoint_standard == "CLSI"
