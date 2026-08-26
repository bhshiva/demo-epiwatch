import os
from typing import Dict, Any, List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from app.deps import get_current_doctor
from app.models import Doctor
from app.services.ocr_service import parse_raw_clinical_text, parse_raw_ast_text
from app.services.clinical_intelligence import (
    audit_lab_isolate,
    audit_clinician_report,
)

router = APIRouter(prefix="/api/v1/ingestion", tags=["ingestion"])


class OCRParseRequest(BaseModel):
    document_type: str = Field(..., description="'clinical_report' or 'lab_isolate'")
    raw_text: Optional[str] = None
    image_base64: Optional[str] = None
    file_name: Optional[str] = None


class ValidateReportRequest(BaseModel):
    exact_age: Optional[int] = None
    sex: str
    district: str
    symptoms: List[str]
    diagnosis: str
    infection_syndrome: str
    infection_origin: str
    diagnosis_status: str = "Confirmed"


class ValidateIsolateRequest(BaseModel):
    specimen_type: str
    pathogen: str
    ast_panel: List[Dict[str, Any]]
    patient_sex: Optional[str] = None
    patient_age: Optional[int] = None


SAMPLE_DOCUMENTS = {
    "doctor_pneumonia_prescription": {
        "title": "Clinical Rx: Community-Acquired Pneumonia",
        "document_type": "clinical_report",
        "text": """
CITY GENERAL HOSPITAL - OUTPATIENT PRESCRIPTION & CLINICAL NOTE
Date: 2026-08-26 | Dr. Asha Rao (Reg: MH-12345)
Patient Name: Anil Sharma | Age: 42 yrs | Gender: Male
District: Pune | Origin: Community-acquired
Chief Complaints: High grade fever since 4 days, productive cough with rust-colored sputum, acute shortness of breath and chills.
Vitals: BP 120/80, SpO2 93%, Temp 102.4F
Impression/Diagnosis: Community Acquired Pneumonia (Lower respiratory)
Status: Confirmed | Outcome: Admitted - under treatment
Prescription:
1. Inj Ceftriaxone 1g IV BD
2. Tab Azithromycin 500mg OD x 5 days
3. Tab Paracetamol 650mg TDS
        """.strip(),
    },
    "lab_ast_klebsiella_intrinsic_violation": {
        "title": "Lab AST Sheet: Klebsiella (With Intrinsic Resistance Anomaly)",
        "document_type": "lab_isolate",
        "text": """
APEX MICROBIOLOGY DIAGNOSTICS & RESEARCH
Sample ID: ACC-2026-9042 | Collection Date: 2026-08-25
Specimen: Urine (Midstream Clean Catch)
Culture Result: Growth - organism identified
Pathogen: Klebsiella pneumoniae (>10^5 CFU/mL)
Infection Origin: Community-acquired

ANTIMICROBIAL SUSCEPTIBILITY TEST REPORT (Disk Diffusion / CLSI):
- Ampicillin : Susceptible (Zone: 22mm, MIC: <=2 ug/ml)  [FALSE/ANOMALOUS DATA]
- Amoxicillin-Clavulanate : Resistant (Zone: 12mm)
- Ceftriaxone : Resistant (Zone: 10mm, MIC: >=64 ug/ml)
- Ciprofloxacin : Resistant (Zone: 11mm, MIC: >=4 ug/ml)
- Meropenem : Susceptible (Zone: 28mm, MIC: <=0.5 ug/ml)
- Amikacin : Susceptible (Zone: 24mm, MIC: <=4 ug/ml)
- Co-trimoxazole : Resistant (Zone: 9mm)
        """.strip(),
    },
    "lab_ast_pseudomonas_wound": {
        "title": "Lab AST Sheet: Pseudomonas Wound Isolate (MDR)",
        "document_type": "lab_isolate",
        "text": """
DEPARTMENT OF CLINICAL MICROBIOLOGY
Lab No: ACC-2026-4412 | Date: 2026-08-26
Specimen: Wound swab (Post-operative wound)
Culture: Growth - organism identified
Organism: Pseudomonas aeruginosa

AST Results:
- Piperacillin-Tazobactam : Resistant (Zone: 14mm)
- Ceftazidime : Resistant (Zone: 13mm)
- Cefepime : Resistant (Zone: 12mm)
- Meropenem : Resistant (Zone: 11mm)
- Ciprofloxacin : Resistant (Zone: 10mm)
- Amikacin : Resistant (Zone: 12mm)
- Colistin : Susceptible (MIC: 1.0 ug/ml)
        """.strip(),
    },
    "lab_sterile_culture": {
        "title": "Lab Sheet: Sterile Blood Culture (No Growth)",
        "document_type": "lab_isolate",
        "text": """
BLOOD CULTURE AUTOMATED BACT/ALERT REPORT
Sample ID: ACC-2026-1109
Specimen: Blood
Culture Result: No growth after 5 days of automated incubation
Status: Final
Notes: No bacterial or fungal growth observed.
        """.strip(),
    },
}


from app.services.ocr_service import (
    parse_raw_clinical_text,
    parse_raw_ast_text,
    extract_with_google_vision_ocr,
)

@router.post("/ocr-parse")
def parse_ocr_document(
    request: OCRParseRequest,
    current_user: Doctor = Depends(get_current_doctor),
) -> Dict[str, Any]:
    """
    Ingests raw OCR text or image data (via Google Vision OCR) and normalizes entities with clinical intelligence auditing.
    """
    ocr_engine = "Google Vision & Local OCR"
    raw_text = request.raw_text or ""

    if request.image_base64:
        extracted = extract_with_google_vision_ocr(request.image_base64, request.document_type)
        if extracted.strip():
            raw_text = extracted
            ocr_engine = "Google Cloud Vision / Lens Multimodal OCR"
        else:
            # Check if API key was missing
            api_key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
            if not api_key:
                return {
                    "raw_text": "",
                    "ocr_engine": "OCR Engine (Unconfigured)",
                    "extracted": {
                        "full_name": None,
                        "exact_age": None,
                        "age_group": None,
                        "sex": "Other",
                        "district": "Pune",
                        "complaints": None,
                        "diagnosis": None,
                        "diagnosis_status": "Suspected",
                        "infection_syndrome": None,
                        "infection_origin": "Community-acquired",
                        "patient_outcome": "Under review",
                        "symptoms": [],
                    },
                    "intelligence_audit": {
                        "plausibility_score": 0,
                        "status": "Configuration Required",
                        "is_valid": False,
                        "summary": "Google Gemini Vision API key is not configured on the server (set GEMINI_API_KEY in backend/.env).",
                        "findings": [
                            {
                                "category": "configuration",
                                "severity": "WARNING",
                                "title": "Gemini API Key Required",
                                "description": "Set GEMINI_API_KEY in backend/.env to enable multimodal handwriting & document recognition.",
                                "field": "GEMINI_API_KEY",
                                "suggested_action": "Add GEMINI_API_KEY to backend/.env and restart backend server.",
                            }
                        ],
                        "mdr_flag": False,
                    },
                }
            raw_text = "NON_MEDICAL_DOCUMENT"
    elif not raw_text.strip():
        # Fallback to demo template ONLY if user requested empty raw text without an image
        if request.document_type == "clinical_report":
            raw_text = SAMPLE_DOCUMENTS["doctor_pneumonia_prescription"]["text"]
        else:
            raw_text = SAMPLE_DOCUMENTS["lab_ast_klebsiella_intrinsic_violation"]["text"]

    if request.document_type == "clinical_report":
        result = parse_raw_clinical_text(raw_text, ocr_engine=ocr_engine)
    elif request.document_type == "lab_isolate":
        result = parse_raw_ast_text(raw_text, ocr_engine=ocr_engine)
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported document_type '{request.document_type}'. Must be 'clinical_report' or 'lab_isolate'.",
        )

    return result


@router.post("/validate-report")
def validate_report(
    payload: ValidateReportRequest,
    current_user: Doctor = Depends(get_current_doctor),
) -> Dict[str, Any]:
    """
    Real-time clinical intelligence validation for doctor's report submission.
    """
    audit = audit_clinician_report(
        exact_age=payload.exact_age,
        sex=payload.sex,
        district=payload.district,
        symptoms=payload.symptoms,
        diagnosis=payload.diagnosis,
        infection_syndrome=payload.infection_syndrome,
        infection_origin=payload.infection_origin,
        diagnosis_status=payload.diagnosis_status,
    )
    return {
        "plausibility_score": audit.plausibility_score,
        "status": audit.status,
        "is_valid": audit.is_valid,
        "summary": audit.summary,
        "findings": audit.findings,
        "mdr_flag": audit.mdr_flag,
    }


@router.post("/validate-isolate")
def validate_isolate(
    payload: ValidateIsolateRequest,
    current_user: Doctor = Depends(get_current_doctor),
) -> Dict[str, Any]:
    """
    Real-time microbiology intelligence validation for AST panel and isolate submission.
    """
    audit = audit_lab_isolate(
        specimen_type=payload.specimen_type,
        pathogen=payload.pathogen,
        ast_panel=payload.ast_panel,
        patient_sex=payload.patient_sex,
        patient_age=payload.patient_age,
    )
    return {
        "plausibility_score": audit.plausibility_score,
        "status": audit.status,
        "is_valid": audit.is_valid,
        "summary": audit.summary,
        "findings": audit.findings,
        "mdr_flag": audit.mdr_flag,
    }


@router.get("/sample-documents")
def get_sample_documents() -> Dict[str, Any]:
    """
    Returns curated testing and training sample documents for OCR testing.
    """
    return SAMPLE_DOCUMENTS
