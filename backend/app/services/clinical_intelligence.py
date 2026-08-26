from typing import Dict, List, Any, Optional
from dataclasses import dataclass, asdict

from app.services.normalization_service import ANTIBIOTIC_CATALOG


@dataclass
class AnomalyFinding:
    category: str       # "intrinsic_resistance", "specimen_pathogen_mismatch", "demographic_mismatch", "symptom_incongruity", "data_quality"
    severity: str       # "CRITICAL", "WARNING", "INFO"
    title: str
    description: str
    field: Optional[str] = None
    suggested_action: Optional[str] = None


@dataclass
class IntelligenceAuditResult:
    plausibility_score: int         # 0 - 100
    status: str                     # "VALID", "WARNING", "CRITICAL_ANOMALY"
    is_valid: bool
    findings: List[Dict[str, Any]]
    mdr_flag: bool
    summary: str


# EUCAST & CLSI Intrinsic Resistance Rules (Microbiology Expert Rules)
# Pathogen -> List of Drugs that are biologically/intrinsically resistant in wild-type
INTRINSIC_RESISTANCE_RULES: Dict[str, Dict[str, str]] = {
    "Klebsiella pneumoniae": {
        "Ampicillin": "Klebsiella pneumoniae carries chromosomal SHV-1 beta-lactamase, conferring universal intrinsic resistance to Ampicillin. Reporting Susceptible indicates laboratory error, disc degradation, or invalid AST data.",
        "Amoxicillin": "Klebsiella pneumoniae is intrinsically resistant to plain aminopenicillins (Amoxicillin/Ampicillin).",
    },
    "Pseudomonas aeruginosa": {
        "Ampicillin": "Pseudomonas aeruginosa is intrinsically resistant to Ampicillin due to inducible AmpC beta-lactamase and low outer membrane permeability.",
        "Amoxicillin": "Pseudomonas aeruginosa is intrinsically resistant to Amoxicillin.",
        "Amoxicillin-Clavulanate": "Pseudomonas aeruginosa is intrinsically resistant to Amoxicillin-Clavulanate (beta-lactamase inhibitors do not inhibit AmpC effectively).",
        "Ceftriaxone": "Pseudomonas aeruginosa has intrinsic resistance to narrow/extended-spectrum cephalosporins like Ceftriaxone and Cefotaxime.",
        "Cefotaxime": "Pseudomonas aeruginosa is intrinsically resistant to Cefotaxime.",
        "Cefixime": "Pseudomonas aeruginosa is intrinsically resistant to Cefixime.",
        "Ertapenem": "Pseudomonas aeruginosa lacks active uptake pathways for Ertapenem and is intrinsically non-susceptible.",
        "Co-trimoxazole": "Pseudomonas aeruginosa is intrinsically resistant to Trimethoprim-Sulfamethoxazole via multidrug efflux pumps (MexAB-OprM).",
        "Tetracycline": "Pseudomonas aeruginosa is intrinsically resistant to Tetracyclines.",
        "Doxycycline": "Pseudomonas aeruginosa is intrinsically resistant to Doxycycline.",
    },
    "Acinetobacter baumannii": {
        "Ampicillin": "Acinetobacter baumannii is intrinsically resistant to Ampicillin.",
        "Amoxicillin": "Acinetobacter baumannii is intrinsically resistant to Amoxicillin.",
        "Amoxicillin-Clavulanate": "Acinetobacter baumannii is intrinsically resistant to Amoxicillin-Clavulanate.",
        "Ertapenem": "Acinetobacter baumannii has poor affinity/penetration for Ertapenem and is intrinsically non-susceptible.",
        "Azithromycin": "Acinetobacter baumannii is intrinsically resistant to Macrolides.",
    },
    "Enterococcus species": {
        "Ceftriaxone": "Enterococcus species are intrinsically resistant to Cephalosporins (all generations) due to low affinity penicillin-binding proteins (PBP4/PBP5).",
        "Cefotaxime": "Enterococcus species are intrinsically resistant to Cephalosporins.",
        "Ceftazidime": "Enterococcus species are intrinsically resistant to Cephalosporins.",
        "Cefepime": "Enterococcus species are intrinsically resistant to Cephalosporins.",
        "Cefixime": "Enterococcus species are intrinsically resistant to Cephalosporins.",
        "Co-trimoxazole": "Enterococcus species can absorb exogenous folates in vivo and are intrinsically clinically resistant to Trimethoprim-Sulfamethoxazole.",
        "Clindamycin": "Enterococci are intrinsically resistant to Lincosamides (Clindamycin).",
    },
    "Staphylococcus aureus": {
        "Colistin": "Gram-positive organisms (Staphylococcus aureus) lack the outer LPS membrane and are intrinsically resistant to Polymyxins (Colistin).",
        "Aztreonam": "Staphylococcus aureus is intrinsically resistant to Monobactams.",
    },
    "Streptococcus pneumoniae": {
        "Colistin": "Streptococcus pneumoniae (Gram-positive) is intrinsically resistant to Colistin.",
        "Gentamicin": "Streptococcus pneumoniae shows intrinsic low-level aminoglycoside resistance (ineffective as monotherapy).",
        "Amikacin": "Streptococcus pneumoniae shows intrinsic low-level aminoglycoside resistance.",
        "Tobramycin": "Streptococcus pneumoniae shows intrinsic low-level aminoglycoside resistance.",
    },
}

# Specimen vs Pathogen Implausibility Rules
SPECIMEN_PATHOGEN_INCONGRUITIES: List[Dict[str, Any]] = [
    {
        "pathogen": "Neisseria gonorrhoeae",
        "forbidden_specimens": ["Stool", "Sputum"],
        "reason": "Neisseria gonorrhoeae is a fastidious genital/mucosal pathogen. Isolation from stool or routine sputum strongly suggests sample misidentification or contamination.",
    },
    {
        "pathogen": "Streptococcus pneumoniae",
        "forbidden_specimens": ["Urethral swab", "Cervical swab"],
        "reason": "Streptococcus pneumoniae is a respiratory and invasive pathogen; isolation from genital swabs is clinically atypical and indicates probable Streptococcus agalactiae (GBS) confusion or specimen mix-up.",
    },
    {
        "pathogen": "Shigella species",
        "forbidden_specimens": ["Sputum", "Cerebrospinal fluid"],
        "reason": "Shigella is an enteric pathogen causing bacillary dysentery; recovery from sputum or CSF is exceptionally rare and warrants laboratory re-verification.",
    },
]


def audit_lab_isolate(
    *,
    specimen_type: str,
    pathogen: str,
    ast_panel: List[Dict[str, Any]],
    patient_sex: Optional[str] = None,
    patient_age: Optional[int] = None,
) -> IntelligenceAuditResult:
    """
    Performs comprehensive microbiology and AST validation on an isolate payload.
    """
    findings: List[AnomalyFinding] = []
    score = 100
    resistant_classes = set()

    # 1. Biological Sex vs Anatomical Specimen
    if patient_sex == "Male" and specimen_type == "Cervical swab":
        findings.append(
            AnomalyFinding(
                category="demographic_mismatch",
                severity="CRITICAL",
                title="Anatomical / Biological Sex Contradiction",
                description="Specimen is recorded as 'Cervical swab' for a Male patient. This is biologically impossible.",
                field="specimen_type",
                suggested_action="Verify patient gender or specimen collection type.",
            )
        )
        score -= 40

    # 2. Specimen vs Pathogen Incongruity
    for rule in SPECIMEN_PATHOGEN_INCONGRUITIES:
        if pathogen == rule["pathogen"] and specimen_type in rule["forbidden_specimens"]:
            findings.append(
                AnomalyFinding(
                    category="specimen_pathogen_mismatch",
                    severity="WARNING",
                    title="Atypical Specimen-Pathogen Association",
                    description=f"{pathogen} isolated from '{specimen_type}'. {rule['reason']}",
                    field="pathogen",
                    suggested_action="Confirm microbiology bench identification and Gram stain characteristics.",
                )
            )
            score -= 25

    # 3. Antibiotic Susceptibility & Intrinsic Resistance Validation
    intrinsic_map = INTRINSIC_RESISTANCE_RULES.get(pathogen, {})
    for ast in ast_panel:
        drug = ast.get("antibiotic")
        result = ast.get("ast_result")
        ab_class = ast.get("antibiotic_class")

        if result == "Resistant":
            if not ab_class and drug in ANTIBIOTIC_CATALOG:
                ab_class = ANTIBIOTIC_CATALOG[drug]["class"]
            if ab_class:
                resistant_classes.add(ab_class)

        if drug in intrinsic_map and result == "Susceptible":
            explanation = intrinsic_map[drug]
            findings.append(
                AnomalyFinding(
                    category="intrinsic_resistance",
                    severity="CRITICAL",
                    title=f"Intrinsic Resistance Violation ({drug})",
                    description=f"Pathogen '{pathogen}' is reported as 'Susceptible' to {drug}. {explanation}",
                    field=f"ast_{drug}",
                    suggested_action=f"Change {drug} result to 'Resistant' or 'Not tested' per EUCAST/CLSI expert rules.",
                )
            )
            score -= 30

    # Check for MDR (Multi-Drug Resistance: >= 3 distinct antibiotic classes resistant)
    mdr_flag = len(resistant_classes) >= 3
    if mdr_flag:
        findings.append(
            AnomalyFinding(
                category="epidemiological_alert",
                severity="INFO",
                title="Multi-Drug Resistant (MDR) Isolate Detected",
                description=f"Isolate shows resistance across {len(resistant_classes)} antimicrobial classes: {', '.join(sorted(resistant_classes))}.",
                field="ast_panel",
                suggested_action="Ensure hospital infection prevention and control (IPC) precautions are notified.",
            )
        )

    # 4. AST Panel Completeness / Plausibility
    valid_tested_count = sum(1 for ast in ast_panel if ast.get("ast_result") in ["Susceptible", "Intermediate", "Resistant"])
    if pathogen != "Other" and valid_tested_count == 0 and len(ast_panel) > 0:
        findings.append(
            AnomalyFinding(
                category="data_quality",
                severity="WARNING",
                title="Uninterpreted AST Panel",
                description="Organism is identified, but all tested antibiotics are marked 'Not tested' or uninterpreted.",
                field="ast_panel",
                suggested_action="Record S/I/R interpretations for clinical stewardship.",
            )
        )
        score -= 15

    # Final scoring and status categorization
    score = max(0, min(100, score))
    has_critical = any(f.severity == "CRITICAL" for f in findings)
    has_warning = any(f.severity == "WARNING" for f in findings)

    if has_critical or score < 60:
        status = "CRITICAL_ANOMALY"
        is_valid = False
        summary = f"Detected {len([f for f in findings if f.severity == 'CRITICAL'])} critical contradiction(s) in microbiology / AST data."
    elif has_warning or score < 85:
        status = "WARNING"
        is_valid = True
        summary = "Microbiology data has clinical warnings requiring practitioner review."
    else:
        status = "VALID"
        is_valid = True
        summary = "All microbiology, AST, and specimen checks validated successfully."

    return IntelligenceAuditResult(
        plausibility_score=score,
        status=status,
        is_valid=is_valid,
        findings=[asdict(f) for f in findings],
        mdr_flag=mdr_flag,
        summary=summary,
    )


def audit_clinician_report(
    *,
    exact_age: Optional[int],
    sex: str,
    district: str,
    symptoms: List[str],
    diagnosis: str,
    infection_syndrome: str,
    infection_origin: str,
    diagnosis_status: str,
) -> IntelligenceAuditResult:
    """
    Performs clinical coherence and false-data detection on a doctor's report.
    """
    findings: List[AnomalyFinding] = []
    score = 100

    # 1. Symptom vs Syndrome Incoherence
    symptoms_lower = [s.lower() for s in symptoms]

    if infection_syndrome == "Pneumonia / Lower respiratory":
        respiratory_symptoms = ["cough", "shortness of breath", "fever", "chills"]
        has_resp = any(s in symptoms_lower for s in respiratory_symptoms)
        if not has_resp and len(symptoms) > 0:
            findings.append(
                AnomalyFinding(
                    category="symptom_incongruity",
                    severity="WARNING",
                    title="Clinical Syndrome-Symptom Discrepancy",
                    description="Syndrome is classified as 'Pneumonia / Lower respiratory' but no respiratory symptoms (Cough, Shortness of Breath, Fever) are recorded.",
                    field="infection_syndrome",
                    suggested_action="Review presenting symptoms or verify diagnosis classification.",
                )
            )
            score -= 20

    if infection_syndrome == "Urinary tract":
        urinary_symptoms = ["dysuria", "fever", "abdominal cramps"]
        has_uri = any(s in symptoms_lower for s in urinary_symptoms)
        if not has_uri and len(symptoms) > 0:
            findings.append(
                AnomalyFinding(
                    category="symptom_incongruity",
                    severity="WARNING",
                    title="Atypical Symptom Profile for UTI",
                    description="Syndrome is classified as 'Urinary tract' but characteristic symptoms (Dysuria, Fever, Abdominal Cramps) are not selected.",
                    field="infection_syndrome",
                    suggested_action="Confirm presence of urinary symptoms or adjust syndrome.",
                )
            )
            score -= 15

    # 2. Demographic plausibility
    if exact_age is not None:
        if exact_age < 0 or exact_age > 125:
            findings.append(
                AnomalyFinding(
                    category="demographic_mismatch",
                    severity="CRITICAL",
                    title="Implausible Patient Age",
                    description=f"Patient age {exact_age} is outside plausible human range (0-125 years).",
                    field="exact_age",
                    suggested_action="Correct exact age or date of birth.",
                )
            )
            score -= 50

    # 3. Completeness & Data Quality Check
    if not symptoms:
        findings.append(
            AnomalyFinding(
                category="data_quality",
                severity="WARNING",
                title="Missing Presenting Symptoms",
                description="No presenting symptoms recorded. Complete clinical profiles improve epidemiological surveillance accuracy.",
                field="symptoms",
                suggested_action="Select all observed symptoms from the clinical catalog.",
            )
        )
        score -= 15

    score = max(0, min(100, score))
    has_critical = any(f.severity == "CRITICAL" for f in findings)
    has_warning = any(f.severity == "WARNING" for f in findings)

    if has_critical or score < 60:
        status = "CRITICAL_ANOMALY"
        is_valid = False
        summary = "Critical clinical data inconsistency detected."
    elif has_warning or score < 85:
        status = "WARNING"
        is_valid = True
        summary = "Report contains clinical advisory warnings."
    else:
        status = "VALID"
        is_valid = True
        summary = "Clinical report data verified and consistent."

    return IntelligenceAuditResult(
        plausibility_score=score,
        status=status,
        is_valid=is_valid,
        findings=[asdict(f) for f in findings],
        mdr_flag=False,
        summary=summary,
    )
