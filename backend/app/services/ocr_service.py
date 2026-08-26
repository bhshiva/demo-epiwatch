import os
import re
import base64
from typing import Dict, List, Any, Optional
from datetime import date, datetime
from dotenv import load_dotenv

load_dotenv()

from app.services.normalization_service import (
    normalize_sex,
    normalize_district,
    normalize_pathogen,
    normalize_antibiotic,
    normalize_ast_result,
    normalize_specimen,
    normalize_syndrome,
    normalize_origin,
    normalize_symptoms,
    age_to_age_group,
    ANTIBIOTIC_CATALOG,
)
from app.services.clinical_intelligence import (
    audit_lab_isolate,
    audit_clinician_report,
)


def extract_with_google_vision_ocr(image_base64: str, document_type: str) -> str:
    """
    Uses Google Cloud Vision / Gemini Vision multimodal OCR to extract structured
    text from uploaded images of prescriptions, clinical notes, or lab sheets.
    """
    api_key = (os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY") or "").strip()
    if not api_key or not image_base64:
        return ""

    try:
        from google import genai
        client = genai.Client(api_key=api_key)
        
        prompt = (
            "You are an expert clinical and medical document OCR engine.\n\n"
            "TASK:\n"
            "1. Inspect the provided image carefully.\n"
            "2. If this image is NOT a medical document (for example: math equations, physics, homework, "
            "code, diagrams, random notes, receipts, memes, or general non-healthcare content), "
            "respond ONLY with:\nNON_MEDICAL_DOCUMENT\n\n"
            "3. If this IS a valid medical prescription, hospital slip, or doctor's clinical notes, "
            "transcribe all text accurately:\n"
            "- Patient Name, Age, Sex, District/City\n"
            "- Chief Complaints, Symptoms, Duration\n"
            "- Clinical Diagnosis / Infection Syndrome / Origin\n"
            "- Prescriptions (Medicines, Dosages, Frequency, Days)\n"
            "- Outcome / Advice"
        )
        if document_type == "lab_isolate":
            prompt = (
                "You are an expert clinical microbiology OCR engine.\n\n"
                "TASK:\n"
                "1. Inspect the provided image carefully.\n"
                "2. If this image is NOT a microbiology lab or AST susceptibility report, "
                "respond ONLY with:\nNON_MEDICAL_DOCUMENT\n\n"
                "3. If this IS a lab report, transcribe:\n"
                "- Accession / Sample ID, Specimen Type\n"
                "- Culture Result, Pathogen / Organism identified\n"
                "- Complete AST Susceptibility Panel (Antibiotic, Zone diameter in mm, MIC in ug/mL, and Result: Susceptible/Intermediate/Resistant)"
            )

        # Remove header if present (e.g. data:image/png;base64,...)
        clean_b64 = image_base64
        if "," in clean_b64:
            clean_b64 = clean_b64.split(",", 1)[1]
        
        image_bytes = base64.b64decode(clean_b64)

        # Try gemini-3.6-flash, fallback to gemini-2.5-flash
        for model_name in ["gemini-3.6-flash", "gemini-2.5-flash", "gemini-1.5-flash"]:
            try:
                response = client.models.generate_content(
                    model=model_name,
                    contents=[
                        genai.types.Part.from_bytes(data=image_bytes, mime_type="image/jpeg"),
                        prompt,
                    ],
                )
                if response and response.text:
                    return response.text.strip()
            except Exception as model_err:
                print(f"[OCR] Model {model_name} attempt failed: {model_err}")
                continue

        return ""
    except Exception as e:
        print(f"[OCR] Error during Gemini Vision OCR: {e}")
        return ""


def parse_raw_clinical_text(text: str, ocr_engine: str = "Google Vision & Local OCR") -> Dict[str, Any]:
    """
    Parses unstructured or semi-structured clinical text from an OCR scan of a doctor's report.
    Enforces strict relevance checks to reject non-medical images or formulas.
    """
    trimmed = text.strip()
    if not trimmed or trimmed == "NON_MEDICAL_DOCUMENT":
        return {
            "raw_text": text,
            "ocr_engine": ocr_engine,
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
                "status": "Invalid Document",
                "is_valid": False,
                "summary": "Non-medical or unreadable document. No clinical diagnosis or prescription data detected.",
                "findings": ["NON_MEDICAL_DOCUMENT: The scanned content does not contain clinical entities, patient records, or medical prescriptions."],
                "mdr_flag": False,
            },
        }

    clean_lines = [re.sub(r"^[\-\*•\s]+", "", re.sub(r"[\*#_`]", "", l)).strip() for l in text.splitlines() if l.strip()]
    full_text = " ".join(clean_lines)

    extracted_name = None
    extracted_age = None
    extracted_sex = None
    extracted_district = None
    extracted_complaints = None
    extracted_diagnosis = None
    extracted_syndrome = None
    extracted_origin = None
    extracted_outcome = None
    extracted_symptoms: List[str] = []

    # 1. Line-by-line structured search (high precision for formatted outputs)
    for line in clean_lines:
        if not extracted_name:
            m = re.search(r"^(?:patient name|pt name|name)\s*[:\-]\s*([A-Za-z\.\s]+?)(?:\s*[,;]|\s+age\b|\s+sex\b|$)", line, re.IGNORECASE)
            if not m and not any(line.lower().startswith(skip) for skip in ["patient details", "patient info", "patient record"]):
                m = re.search(r"^patient\s*[:\-]\s*([A-Za-z\.\s]+?)(?:\s*[,;]|\s+age\b|\s+sex\b|$)", line, re.IGNORECASE)
            if m and len(m.group(1).strip()) > 1:
                candidate = m.group(1).strip()
                if candidate.lower() not in ["details", "info", "record", "name"]:
                    extracted_name = candidate
        if not extracted_age:
            m = re.search(r"(?:age|years|yrs|yr)\s*[:\-\/]?\s*(\d{1,3})", line, re.IGNORECASE)
            if not m:
                m = re.search(r"(?:age\/gender|age\/sex)\s*[:\-]?\s*(\d{1,3})", line, re.IGNORECASE)
            if m:
                try:
                    extracted_age = int(m.group(1))
                except ValueError:
                    pass
        if not extracted_sex:
            m = re.search(r"(?:sex|gender|age\/gender|age\/sex)\s*[:\-]?\s*(?:\d{1,3}\s*)?(male|female|other|m\b|f\b)", line, re.IGNORECASE)
            if m:
                extracted_sex = m.group(1).strip()
        if not extracted_district:
            m = re.search(r"(?:district|city|location|address)\s*[:\-]\s*([A-Za-z]+)", line, re.IGNORECASE)
            if m:
                extracted_district = m.group(1).strip()
        if not extracted_diagnosis:
            m = re.search(r"^(?:diagnosis|dx|impression|condition)\s*[:\-]\s*([^\n;]+)", line, re.IGNORECASE)
            if m:
                extracted_diagnosis = m.group(1).strip()
        if not extracted_complaints:
            m = re.search(r"^(?:chief complaints|complaints|c\/o|history|h\/o)\s*[:\-]\s*([^\n;]+)", line, re.IGNORECASE)
            if m:
                extracted_complaints = m.group(1).strip()

    # 2. Fallback regex search on full text
    if not extracted_name:
        name_match = re.search(r"(?:name|pt name|patient name|patient)\s*[:\-]\s*([A-Za-z\.\s]+?)(?:\s*[\|\n,;]|\s+age\b|\s+sex\b|\s+gender\b|\s+date\b|$)", full_text, re.IGNORECASE)
        if name_match:
            extracted_name = name_match.group(1).strip()

    if not extracted_age:
        age_match = re.search(r"(?:age|yrs|years old|yr)\s*[:\-]?\s*(\d{1,3})", full_text, re.IGNORECASE)
        if age_match:
            try:
                extracted_age = int(age_match.group(1))
            except ValueError:
                pass

    if not extracted_sex:
        sex_match = re.search(r"(?:sex|gender)\s*[:\-]\s*(male|female|other|m\b|f\b)", full_text, re.IGNORECASE)
        if sex_match:
            extracted_sex = sex_match.group(1).strip()

    if not extracted_district:
        district_match = re.search(r"(?:district|city|location|address)\s*[:\-]\s*([A-Za-z]+)", full_text, re.IGNORECASE)
        if district_match:
            extracted_district = district_match.group(1).strip()

    if not extracted_diagnosis:
        diag_match = re.search(r"(?:diagnosis|dx|impression|condition)\s*[:\-]\s*([^\.\n,;]+)", full_text, re.IGNORECASE)
        if diag_match:
            extracted_diagnosis = diag_match.group(1).strip()

    syndrome_match = re.search(r"(?:syndrome|infection syndrome)\s*[:\-]\s*([^\.\n,;]+)", full_text, re.IGNORECASE)
    if syndrome_match:
        extracted_syndrome = syndrome_match.group(1).strip()

    origin_match = re.search(r"(?:origin|infection origin|source)\s*[:\-]\s*([^\.\n,;]+)", full_text, re.IGNORECASE)
    if origin_match:
        extracted_origin = origin_match.group(1).strip()

    if not extracted_complaints:
        complaints_match = re.search(r"(?:complaints|chief complaints|c\/o|history|h\/o)\s*[:\-]\s*([^\.\n;]+)", full_text, re.IGNORECASE)
        if complaints_match:
            extracted_complaints = complaints_match.group(1).strip()

    # Extract symptoms from free text
    extracted_symptoms = normalize_symptoms(full_text)

    # Check for medical keywords / prescription drugs to verify this is a real clinical document
    has_clinical_keywords = any(kw in full_text.lower() for kw in [
        "patient", "dr.", "doctor", "hospital", "clinic", "diagnosis", "rx", "tab", "cap", "mg", "syrup",
        "fever", "cough", "pain", "infection", "complaint", "prescription", "symptoms", "dose", "bp:", "pulse"
    ]) or bool(extracted_symptoms or extracted_diagnosis or extracted_complaints or extracted_name)

    if not has_clinical_keywords:
        return {
            "raw_text": text,
            "ocr_engine": ocr_engine,
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
                "status": "Invalid Document",
                "is_valid": False,
                "summary": "Non-clinical document detected. Mathematical formulas, general notes, or non-medical images cannot be processed.",
                "findings": ["NON_MEDICAL_DOCUMENT: Scanned image contains no medical or prescription entities."],
                "mdr_flag": False,
            },
        }

    # Normalization
    norm_sex, _ = normalize_sex(extracted_sex)
    norm_district, _ = normalize_district(extracted_district)
    norm_syndrome, _, _ = normalize_syndrome(extracted_syndrome or extracted_diagnosis or full_text)
    norm_origin, _ = normalize_origin(extracted_origin or full_text)
    age_group = age_to_age_group(extracted_age) if extracted_age is not None else "25-44"

    # Run Clinical Intelligence Audit
    audit_result = audit_clinician_report(
        exact_age=extracted_age,
        sex=norm_sex,
        district=norm_district,
        symptoms=extracted_symptoms,
        diagnosis=extracted_diagnosis or norm_syndrome,
        infection_syndrome=norm_syndrome,
        infection_origin=norm_origin,
        diagnosis_status="Confirmed" if extracted_diagnosis else "Suspected",
    )

    return {
        "raw_text": text,
        "ocr_engine": ocr_engine,
        "extracted": {
            "full_name": extracted_name or "Patient",
            "exact_age": extracted_age or 35,
            "age_group": age_group,
            "sex": norm_sex,
            "district": norm_district,
            "complaints": extracted_complaints or (full_text[:120] if has_clinical_keywords else "Clinical consultation note"),
            "diagnosis": extracted_diagnosis or norm_syndrome,
            "diagnosis_status": "Confirmed" if extracted_diagnosis else "Suspected",
            "infection_syndrome": norm_syndrome,
            "infection_origin": norm_origin,
            "patient_outcome": "Admitted - under treatment",
            "symptoms": extracted_symptoms,
        },
        "intelligence_audit": {
            "plausibility_score": audit_result.plausibility_score,
            "status": audit_result.status,
            "is_valid": audit_result.is_valid,
            "summary": audit_result.summary,
            "findings": audit_result.findings,
            "mdr_flag": audit_result.mdr_flag,
        },
    }


def parse_raw_ast_text(text: str, ocr_engine: str = "Google Vision & Local OCR") -> Dict[str, Any]:
    """
    Parses unstructured or tabular microbiology culture & AST report text from an OCR scan.
    Enforces validation to reject non-microbiology documents.
    """
    trimmed = text.strip()
    if not trimmed or trimmed == "NON_MEDICAL_DOCUMENT":
        return {
            "raw_text": text,
            "ocr_engine": ocr_engine,
            "extracted": {
                "accession_no": None,
                "test_date": date.today().isoformat(),
                "specimen_type": None,
                "culture_result": None,
                "pathogen": None,
                "infection_origin": "Community-acquired",
                "ast_method": "Disk diffusion",
                "ast_panel": [],
            },
            "intelligence_audit": {
                "plausibility_score": 0,
                "status": "Invalid Document",
                "is_valid": False,
                "summary": "Non-laboratory document detected. No microbiology or AST panels identified.",
                "findings": ["NON_LAB_DOCUMENT: The provided file does not contain AST disk diffusion/MIC data or culture results."],
                "mdr_flag": False,
            },
        }

    lines = [l.strip() for l in text.splitlines() if l.strip()]
    full_text = " ".join(lines)

    extracted_accession = None
    extracted_specimen = None
    extracted_culture = None
    extracted_pathogen = None
    extracted_ast_method = "Disk diffusion"
    extracted_ast_panel: List[Dict[str, Any]] = []

    # Accession No / Lab No
    acc_match = re.search(r"(?:lab no|lab_id|accession|acc no|sample no|specimen id)\s*[:\-]?\s*([A-Za-z0-9\-_]+)", full_text, re.IGNORECASE)
    if acc_match:
        extracted_accession = acc_match.group(1).strip()

    # Specimen Type
    spec_match = re.search(r"(?:specimen|sample type|sample|source)\s*[:\-]\s*([^\.\n,;]+)", full_text, re.IGNORECASE)
    if spec_match:
        extracted_specimen = spec_match.group(1).strip()
    else:
        # Check specimen keywords in text
        for candidate in ["Blood", "Urine", "Sputum", "Stool", "CSF", "Wound swab", "Pus"]:
            if re.search(r"\b" + candidate + r"\b", full_text, re.IGNORECASE):
                extracted_specimen = candidate
                break

    # Pathogen / Organism
    org_match = re.search(r"(?:organism|pathogen|isolate|isolate identified|growth of)\s*[:\-]\s*([^\.\n,;]+)", full_text, re.IGNORECASE)
    if org_match:
        extracted_pathogen = org_match.group(1).strip()
    else:
        # Check common pathogens
        for candidate in ["Escherichia coli", "E. coli", "Klebsiella pneumoniae", "Pseudomonas aeruginosa", "Staphylococcus aureus", "Acinetobacter baumannii", "Salmonella Typhi", "Streptococcus pneumoniae"]:
            if re.search(r"\b" + re.escape(candidate) + r"\b", full_text, re.IGNORECASE):
                extracted_pathogen = candidate
                break

    # Culture result
    if re.search(r"no growth|sterile|negative", full_text, re.IGNORECASE):
        extracted_culture = "No growth"
    elif re.search(r"contaminated", full_text, re.IGNORECASE):
        extracted_culture = "Contaminated"
    elif extracted_pathogen or re.search(r"growth|isolated|organism", full_text, re.IGNORECASE):
        extracted_culture = "Growth - organism identified"
    else:
        extracted_culture = None

    # AST Table Line-by-line Parsing
    parsed_drugs = set()
    for line in lines:
        for drug_name in ANTIBIOTIC_CATALOG.keys():
            aliases = [drug_name.lower()] + ANTIBIOTIC_CATALOG[drug_name]["aliases"]
            found_drug = False
            for alias in aliases:
                pattern = r"\b" + re.escape(alias) + r"\b"
                if re.search(pattern, line, re.IGNORECASE):
                    found_drug = True
                    break

            if found_drug and drug_name not in parsed_drugs:
                parsed_drugs.add(drug_name)

                # Determine AST Result
                ast_res = "Not tested"
                if re.search(r"\b(resistant|res|\bR\b)\b", line, re.IGNORECASE):
                    ast_res = "Resistant"
                elif re.search(r"\b(susceptible|sensitive|sens|\bS\b)\b", line, re.IGNORECASE):
                    ast_res = "Susceptible"
                elif re.search(r"\b(intermediate|mod|\bI\b)\b", line, re.IGNORECASE):
                    ast_res = "Intermediate"

                # Extract MIC / Zone Diameter
                zone_match = re.search(r"(\d{1,2})\s*(?:mm|millimeters)", line, re.IGNORECASE)
                zone_mm = int(zone_match.group(1)) if zone_match else None

                mic_match = re.search(r"([<>=]{1,2})?\s*(\d+(?:\.\d+)?)\s*(?:ug/ml|mcg/ml|mg/l|ug|mg)", line, re.IGNORECASE)
                mic_val = None
                mic_op = None
                if mic_match:
                    mic_op = mic_match.group(1) or "="
                    mic_val = float(mic_match.group(2))

                extracted_ast_panel.append({
                    "antibiotic": drug_name,
                    "antibiotic_class": ANTIBIOTIC_CATALOG[drug_name]["class"],
                    "ast_result": ast_res,
                    "mic_value": mic_val,
                    "mic_operator": mic_op,
                    "zone_diameter_mm": zone_mm,
                    "method": "Disk diffusion",
                })

    # Strict check: is this a real microbiology report?
    if not extracted_pathogen and not extracted_ast_panel and not extracted_specimen:
        return {
            "raw_text": text,
            "ocr_engine": ocr_engine,
            "extracted": {
                "accession_no": None,
                "test_date": date.today().isoformat(),
                "specimen_type": None,
                "culture_result": None,
                "pathogen": None,
                "infection_origin": "Community-acquired",
                "ast_method": "Disk diffusion",
                "ast_panel": [],
            },
            "intelligence_audit": {
                "plausibility_score": 0,
                "status": "Invalid Document",
                "is_valid": False,
                "summary": "Non-laboratory document. No pathogen, specimen, or AST panel detected.",
                "findings": ["NON_LAB_DOCUMENT: The provided content contains no microbiology AST data."],
                "mdr_flag": False,
            },
        }

    # Normalization
    norm_specimen, _, _ = normalize_specimen(extracted_specimen)
    norm_pathogen, _, _ = normalize_pathogen(extracted_pathogen)

    # Run Microbiology Intelligence Audit
    audit_result = audit_lab_isolate(
        specimen_type=norm_specimen,
        pathogen=norm_pathogen,
        ast_panel=extracted_ast_panel,
    )

    return {
        "raw_text": text,
        "ocr_engine": ocr_engine,
        "extracted": {
            "accession_no": extracted_accession or "ACC-2026-8801",
            "test_date": date.today().isoformat(),
            "specimen_type": norm_specimen,
            "culture_result": extracted_culture or "Growth - organism identified",
            "pathogen": norm_pathogen,
            "infection_origin": "Community-acquired",
            "ast_method": extracted_ast_method,
            "ast_panel": extracted_ast_panel,
        },
        "intelligence_audit": {
            "plausibility_score": audit_result.plausibility_score,
            "status": audit_result.status,
            "is_valid": audit_result.is_valid,
            "summary": audit_result.summary,
            "findings": audit_result.findings,
            "mdr_flag": audit_result.mdr_flag,
        },
    }
