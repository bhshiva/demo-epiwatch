from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db import get_session
from app.models import Doctor
from app.schemas import LoginRequest, LoginResponse
from app.auth import (
    verify_password,
    create_access_token,
    record_login_failure,
    record_login_success,
    is_locked,
)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=LoginResponse)
def login(body: LoginRequest, db: Session = Depends(get_session)):
    doctor = db.query(Doctor).filter_by(email=body.email).first()

    if doctor is not None and is_locked(doctor):
        raise HTTPException(
            status_code=status.HTTP_423_LOCKED,
            detail="Account locked due to repeated failed logins. Try again later.",
        )

    if doctor is None or not verify_password(body.password, doctor.password_hash):
        if doctor is not None:
            record_login_failure(doctor)
            db.commit()
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")

    record_login_success(doctor)
    db.commit()

    token = create_access_token(str(doctor.doctor_id), doctor.role)
    return LoginResponse(
        access_token=token,
        role=doctor.role,
        doctor_id=doctor.doctor_id,
        name=doctor.name,
        facility_id=doctor.facility_id,
    )


@router.post("/logout")
def logout():
    return {"status": "ok"}
