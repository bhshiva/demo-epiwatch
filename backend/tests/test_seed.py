from app.db import SessionLocal
from app.models import Doctor
from scripts.seed import seed, SEED_DOCTOR_EMAIL

def test_seed_is_idempotent():
    seed()
    seed()
    db = SessionLocal()
    try:
        count = db.query(Doctor).filter_by(email=SEED_DOCTOR_EMAIL).count()
        assert count == 1
    finally:
        db.close()
