from dotenv import load_dotenv
load_dotenv()

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="EpiWatch API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

from app.routers import (
    auth as auth_router,
    reports as reports_router,
    dashboard as dashboard_router,
    patients as patients_router,
    lab as lab_router,
    applications as applications_router,
    surveillance as surveillance_router,
)

app.include_router(auth_router.router)
app.include_router(reports_router.router)
app.include_router(dashboard_router.router)
app.include_router(patients_router.router)
app.include_router(lab_router.router)
app.include_router(applications_router.router)
app.include_router(surveillance_router.router)

@app.get("/health")
def health():
    return {"status": "ok"}
