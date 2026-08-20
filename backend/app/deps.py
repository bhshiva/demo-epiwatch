import uuid
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
import jwt as pyjwt

from app.db import get_session
from app.auth import decode_access_token
from app.models import Doctor

_bearer = HTTPBearer()


def get_current_doctor(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
    db: Session = Depends(get_session),
) -> Doctor:
    try:
        payload = decode_access_token(credentials.credentials)
    except pyjwt.InvalidTokenError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired token")

    doctor = db.get(Doctor, uuid.UUID(payload["sub"]))
    if doctor is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Doctor not found")
    return doctor


def require_role(*allowed: str):
    """
    Restrict a route to specific roles.

    The role is read from the database row, not the JWT claim. A token issued
    before a role change would otherwise keep its old privileges until it
    expires, which for a 12-hour token is a real window.
    """

    def dependency(user: Doctor = Depends(get_current_doctor)) -> Doctor:
        if user.role not in allowed:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"This action requires one of: {', '.join(allowed)}",
            )
        return user

    return dependency
