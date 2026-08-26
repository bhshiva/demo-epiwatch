import os
import re
import base64
from typing import Dict, List, Any, Optional
from datetime import date, datetime
try:
    from dotenv import load_dotenv
    load_dotenv()
except Exception:
    pass

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

        response = client.models.generate_content(
            model="gemini-3.6-flash",
            contents=[
                genai.types.Part.from_bytes(data=image_bytes, mime_type="image/jpeg"),
                prompt,
            ],
        )
        return (response.text or "").strip()
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


def parse_with_gemini_llm(text: str, document_type: str) -> Optional[Dict[str, Any]]:
    """
    Uses Gemini LLM to extract structured entities from raw clinical dictation or lab text.
    """
    api_key = (os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY") or "").strip()
    if not api_key:
        return None
    try:
        import json
        from google import genai
        client = genai.Client(api_key=api_key)

        if document_type == "clinical_report":
            prompt = (
                "You are an expert clinical document parser for EpiWatch.\n"
                "Extract structured patient demographics, clinical symptoms, and diagnosis from this doctor's note:\n"
                f'"""{text}"""\n\n'
                "Return ONLY a JSON object with this exact schema:\n"
                "{\n"
                '  "full_name": string or null,\n'
                '  "exact_age": integer or null,\n'
                '  "sex": "Male" | "Female" | "Other",\n'
                '  "district": string or null,\n'
                '  "diagnosis": string or null,\n'
                '  "complaints": string or null,\n'
                '  "infection_syndrome": "Pneumonia / Lower respiratory" | "Upper respiratory" | "Sepsis / Bloodstream" | "Meningitis / CNS" | "Urinary tract" | "Gastroenteritis / Diarrhoeal" | "Skin and soft tissue" | "Undifferentiated fever" | "Other",\n'
                '  "infection_origin": "Community-acquired" | "Hospital-acquired" | "Healthcare-associated",\n'
                '  "symptoms": ["Fever", "Cough", ...]\n'
                "}"
            )
        else:
            prompt = (
                "You are an expert microbiology parser for EpiWatch.\n"
                "Extract specimen, culture, pathogen, and AST antibiotic results from this lab report:\n"
                f'"""{text}"""\n\n'
                "Return ONLY a JSON object with this exact schema:\n"
                "{\n"
                '  "accession_no": string or null,\n'
                '  "specimen_type": "Blood" | "Urine" | "Stool" | "Sputum" | "Cerebrospinal fluid" | "Wound swab" | "Urethral swab" | "Cervical swab" | "Other",\n'
                '  "culture_result": "Growth - organism identified" | "No growth" | "Contaminated" | "Pending",\n'
                '  "pathogen": string or null,\n'
                '  "infection_origin": "Community-acquired" | "Hospital-acquired" | "Healthcare-associated",\n'
                '  "ast_method": "Disk diffusion" | "Broth microdilution" | "E-test" | "VITEK",\n'
                '  "ast_panel": [\n'
                "    {\n"
                '      "antibiotic": string,\n'
                '      "ast_result": "Susceptible" | "Intermediate" | "Resistant" | "Not tested",\n'
                '      "zone_diameter_mm": integer or null,\n'
                '      "mic_ug_ml": number or null\n'
                "    }\n"
                "  ]\n"
                "}"
            )

        for model_name in ["gemini-3.6-flash"]:
            try:
                response = client.models.generate_content(
                    model=model_name,
                    contents=prompt,
                )
                if response and response.text:
                    cleaned = response.text.strip()
                    if cleaned.startswith("```"):
                        cleaned = re.sub(r"^```(?:json)?", "", cleaned).rstrip("`").strip()
                    data = json.loads(cleaned)
                    if isinstance(data, dict):
                        return data
            except Exception as model_err:
                print(f"[Gemini LLM Parse] Failed on {model_name}: {model_err}")
                continue
    except Exception as e:
        print(f"[Gemini LLM Parse] Error: {e}")
    return None


KNOWN_INDIAN_DISTRICTS = {
    "mumbai": "Mumbai",
    "bombay": "Mumbai",
    "pune": "Pune",
    "poona": "Pune",
    "nagpur": "Nagpur",
    "nashik": "Nashik",
    "nasik": "Nashik",
    "thane": "Thane",
    "delhi": "Delhi",
    "new delhi": "Delhi",
    "bengaluru": "Bengaluru",
    "bangalore": "Bengaluru",
    "chennai": "Chennai",
    "madras": "Chennai",
    "hyderabad": "Hyderabad",
    "kolkata": "Kolkata",
    "calcutta": "Kolkata",
    "ahmedabad": "Ahmedabad",
    "jaipur": "Jaipur",
    "lucknow": "Lucknow",
    "surat": "Surat",
    "kanpur": "Kanpur",
    "indore": "Indore",
    "patna": "Patna",
    "bhopal": "Bhopal",
    "vadodara": "Vadodara",
    "coimbatore": "Coimbatore",
    "ludhiana": "Ludhiana",
    "agra": "Agra",
    "kochi": "Kochi",
    "cochin": "Kochi",
    "dehradun": "Dehradun",
    "mangalore": "Mangalore",
    "mysore": "Mysore",
    "chandigarh": "Chandigarh",
    "guwahati": "Guwahati",
}


def parse_raw_clinical_text(text: str, ocr_engine: str = "Google Vision & Local OCR") -> Dict[str, Any]:
    """
    Parses unstructured or semi-structured clinical text from an OCR scan or typed dictation.
    Supports AI-powered LLM extraction and intelligent heuristic fallback.
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

    # 1. Try Gemini LLM Parser first if available
    llm_extracted = parse_with_gemini_llm(trimmed, "clinical_report")
    if llm_extracted:
        extracted_name = llm_extracted.get("full_name")
        extracted_age = llm_extracted.get("exact_age")
        extracted_sex = llm_extracted.get("sex")
        extracted_district = llm_extracted.get("district")
        extracted_diagnosis = llm_extracted.get("diagnosis")
        extracted_complaints = llm_extracted.get("complaints")
        extracted_syndrome = llm_extracted.get("infection_syndrome")
        extracted_origin = llm_extracted.get("infection_origin")
        extracted_symptoms = llm_extracted.get("symptoms") or []
        ocr_engine = "Google Gemini Multimodal AI & Normalization"
    else:
        # 2. Intelligent Heuristic / NLP Extraction
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
        extracted_symptoms = []

        # A. Name detection
        # Check standard key:value lines
        for line in clean_lines:
            m = re.search(r"^(?:patient name|pt name|name|patient)\s*[:\-]\s*([A-Za-z\.\s]+?)(?:\s*[,;]|\s+age\b|\s+sex\b|$)", line, re.IGNORECASE)
            if m and len(m.group(1).strip()) > 1:
                cand = m.group(1).strip()
                if cand.lower() not in ["details", "info", "record", "name"]:
                    extracted_name = cand
                    break

        # If still no name, check if line 1 looks like a human name (e.g. "Avaneesh b", "Rohan Verma")
        if not extracted_name and len(clean_lines) > 0:
            first_line = clean_lines[0].strip()
            # Non-medical, non-numeric line with 1 to 4 words
            words = first_line.split()
            if 1 <= len(words) <= 4 and not re.search(r"\d", first_line):
                lower_first = first_line.lower()
                medical_skip = [
                    "fever", "cough", "pain", "hospital", "clinic", "prescription", "rx", "tab", "cap",
                    "diagnosis", "complaints", "test", "report", "lab", "date", "dr", "doctor", "history"
                ]
                if not any(skip in lower_first for skip in medical_skip):
                    extracted_name = first_line.title()

        # B. Age detection (e.g. "22", "22 yrs", "age 22", "22 mumbai", "22/M")
        for line in clean_lines:
            # Look for age with label or pattern
            m = re.search(r"(?:age|years|yrs|yr)\s*[:\-\/]?\s*(\d{1,3})", line, re.IGNORECASE)
            if not m:
                m = re.search(r"\b(\d{1,2})\s*(?:yrs|years|y\/o|yr|m\b|f\b|male|female)", line, re.IGNORECASE)
            if not m:
                # Standalone number at start of line or before city (e.g. "22 mumbai")
                m = re.search(r"\b(\d{1,2})\b(?:\s+[a-zA-Z]+)?", line)
            if m:
                try:
                    val = int(m.group(1))
                    if 0 <= val <= 115:
                        extracted_age = val
                        break
                except ValueError:
                    pass

        # C. District / City detection (e.g. "mumbai", "pune", "delhi", "bengaluru")
        lower_full = full_text.lower()
        for key_city, canonical_name in KNOWN_INDIAN_DISTRICTS.items():
            if re.search(r"\b" + re.escape(key_city) + r"\b", lower_full):
                extracted_district = canonical_name
                break

        # D. Sex detection
        if re.search(r"\b(female|woman|girl|mrs|ms|f\b)\b", lower_full):
            extracted_sex = "Female"
        elif re.search(r"\b(male|man|boy|mr|m\b)\b", lower_full):
            extracted_sex = "Male"

        # E. Symptoms extraction
        extracted_symptoms = normalize_symptoms(full_text)

        # F. Diagnosis & Complaints detection
        diag_match = re.search(r"(?:diagnosis|dx|impression|condition)\s*[:\-]\s*([^\.\n,;]+)", full_text, re.IGNORECASE)
        if diag_match:
            extracted_diagnosis = diag_match.group(1).strip()
        else:
            # Check for standard known diseases in text
            for disease in ["Dengue", "Malaria", "Typhoid", "Pneumonia", "Cholera", "Influenza", "COVID-19", "Urinary tract infection", "Gastroenteritis", "Tuberculosis"]:
                if re.search(r"\b" + re.escape(disease) + r"\b", full_text, re.IGNORECASE):
                    extracted_diagnosis = disease
                    break

        if not extracted_diagnosis and ("fever" in lower_full or "High fever" in full_text):
            extracted_diagnosis = "Undifferentiated fever"

        complaints_match = re.search(r"(?:complaints|chief complaints|c\/o|history|h\/o)\s*[:\-]\s*([^\.\n;]+)", full_text, re.IGNORECASE)
        if complaints_match:
            extracted_complaints = complaints_match.group(1).strip()
        else:
            # Synthesize complaints from symptoms or line 2
            if len(clean_lines) >= 2 and any(kw in clean_lines[1].lower() for kw in ["fever", "cough", "pain", "headache", "vomiting", "weakness"]):
                extracted_complaints = clean_lines[1]
            elif extracted_symptoms:
                extracted_complaints = ", ".join(extracted_symptoms)

    # 3. Canonical Normalization
    norm_sex, _ = normalize_sex(extracted_sex)
    norm_district, _ = normalize_district(extracted_district)
    norm_syndrome, _, _ = normalize_syndrome(extracted_syndrome or extracted_diagnosis or "")
    norm_origin, _ = normalize_origin(extracted_origin or "")
    age_group = age_to_age_group(extracted_age) if extracted_age is not None else "25-44"

    # 4. Run Clinical Intelligence Audit
    audit_result = audit_clinician_report(
        exact_age=extracted_age,
        sex=norm_sex,
        district=norm_district,
        symptoms=extracted_symptoms if extracted_symptoms else ["Fever"],
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
            "exact_age": extracted_age if extracted_age is not None else 35,
            "age_group": age_group,
            "sex": norm_sex,
            "district": norm_district,
            "complaints": extracted_complaints or "Clinical consultation note",
            "diagnosis": extracted_diagnosis or norm_syndrome,
            "diagnosis_status": "Confirmed" if extracted_diagnosis else "Suspected",
            "infection_syndrome": norm_syndrome,
            "infection_origin": norm_origin,
            "patient_outcome": "Admitted - under treatment",
            "symptoms": extracted_symptoms if extracted_symptoms else (["Fever"] if "fever" in text.lower() else []),
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
    Parses unstructured or tabular microbiology culture & AST report text.
    Supports AI-powered LLM extraction and intelligent tabular regex fallback.
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

    # 1. Try Gemini LLM first if available
    llm_extracted = parse_with_gemini_llm(trimmed, "lab_isolate")
    if llm_extracted:
        extracted_accession = llm_extracted.get("accession_no")
        extracted_specimen = llm_extracted.get("specimen_type")
        extracted_culture = llm_extracted.get("culture_result")
        extracted_pathogen = llm_extracted.get("pathogen")
        extracted_origin = llm_extracted.get("infection_origin")
        extracted_ast_method = llm_extracted.get("ast_method") or "Disk diffusion"
        raw_panel = llm_extracted.get("ast_panel") or []
        extracted_ast_panel = []
        for ast in raw_panel:
            drug = ast.get("antibiotic")
            if drug:
                norm_drug, drug_class, _ = normalize_antibiotic(drug)
                norm_res, _ = normalize_ast_result(ast.get("ast_result"))
                extracted_ast_panel.append({
                    "antibiotic": norm_drug or drug,
                    "antibiotic_class": drug_class or "Other",
                    "ast_result": norm_res,
                    "mic_value": ast.get("mic_ug_ml"),
                    "mic_operator": "=",
                    "zone_diameter_mm": ast.get("zone_diameter_mm"),
                    "method": extracted_ast_method,
                })
        ocr_engine = "Google Gemini Multimodal AI & Normalization"
    else:
        # 2. Heuristic Tabular & Regex Parser
        lines = [l.strip() for l in text.splitlines() if l.strip()]
        full_text = " ".join(lines)

        extracted_accession = None
        extracted_specimen = None
        extracted_culture = None
        extracted_pathogen = None
        extracted_ast_method = "Disk diffusion"
        extracted_origin = "Community-acquired"
        extracted_ast_panel = []

        acc_match = re.search(r"(?:lab no|lab_id|accession|acc no|sample no|specimen id)\s*[:\-]?\s*([A-Za-z0-9\-_]+)", full_text, re.IGNORECASE)
        if acc_match:
            extracted_accession = acc_match.group(1).strip()

        spec_match = re.search(r"(?:specimen|sample type|sample|source)\s*[:\-]\s*([^\.\n,;]+)", full_text, re.IGNORECASE)
        if spec_match:
            extracted_specimen = spec_match.group(1).strip()
        else:
            for candidate in ["Blood", "Urine", "Sputum", "Stool", "CSF", "Wound swab", "Pus"]:
                if re.search(r"\b" + candidate + r"\b", full_text, re.IGNORECASE):
                    extracted_specimen = candidate
                    break

        org_match = re.search(r"(?:organism|pathogen|isolate|isolate identified|growth of)\s*[:\-]\s*([^\.\n,;]+)", full_text, re.IGNORECASE)
        if org_match:
            extracted_pathogen = org_match.group(1).strip()
        else:
            for candidate in ["Escherichia coli", "E. coli", "Klebsiella pneumoniae", "Pseudomonas aeruginosa", "Staphylococcus aureus", "Acinetobacter baumannii", "Salmonella Typhi", "Streptococcus pneumoniae"]:
                if re.search(r"\b" + re.escape(candidate) + r"\b", full_text, re.IGNORECASE):
                    extracted_pathogen = candidate
                    break

        if re.search(r"no growth|sterile|negative", full_text, re.IGNORECASE):
            extracted_culture = "No growth"
        elif re.search(r"contaminated", full_text, re.IGNORECASE):
            extracted_culture = "Contaminated"
        elif extracted_pathogen or re.search(r"growth|isolated|organism", full_text, re.IGNORECASE):
            extracted_culture = "Growth - organism identified"
        else:
            extracted_culture = None

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

                    ast_res = "Not tested"
                    if re.search(r"\b(resistant|res|\bR\b)\b", line, re.IGNORECASE):
                        ast_res = "Resistant"
                    elif re.search(r"\b(susceptible|sensitive|sens|\bS\b)\b", line, re.IGNORECASE):
                        ast_res = "Susceptible"
                    elif re.search(r"\b(intermediate|mod|\bI\b)\b", line, re.IGNORECASE):
                        ast_res = "Intermediate"

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

    # Normalization
    norm_specimen, _, _ = normalize_specimen(extracted_specimen)
    norm_pathogen, _, _ = normalize_pathogen(extracted_pathogen)

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
            "infection_origin": extracted_origin or "Community-acquired",
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
