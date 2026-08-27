import os
from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase

load_dotenv()

DATABASE_URL = os.environ["DATABASE_URL"]

# SQLAlchemy defaults a bare "postgresql://" URL to the psycopg2 dialect, but
# this project installs psycopg (psycopg3) per requirements.txt, not psycopg2.
# Normalize the scheme so SQLAlchemy loads the psycopg3 dialect that is
# actually installed.
_SQLALCHEMY_URL = DATABASE_URL
if _SQLALCHEMY_URL.startswith("postgresql://"):
    _SQLALCHEMY_URL = _SQLALCHEMY_URL.replace("postgresql://", "postgresql+psycopg://", 1)

engine = create_engine(
    _SQLALCHEMY_URL,
    pool_pre_ping=True,
    pool_recycle=300,
    connect_args={
        "prepare_threshold": None,
        "connect_timeout": 15,
    },
)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)

class Base(DeclarativeBase):
    pass

def get_session():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
