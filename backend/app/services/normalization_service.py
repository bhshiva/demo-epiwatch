import re
from typing import Dict, List, Optional, Tuple, Any

# Canonical Catalogs
STANDARD_SEXES = ["Male", "Female", "Other"]
STANDARD_AGE_GROUPS = ["0-4", "5-14", "15-24", "25-44", "45-64", "65+"]
STANDARD_DISTRICTS = [
    "Mumbai", "Pune", "Nagpur", "Nashik", "Thane", "Delhi", "Bengaluru",
    "Chennai", "Hyderabad", "Kolkata", "Ahmedabad", "Jaipur", "Lucknow"
]
STANDARD_SPECIMENS = [
    "Blood", "Urine", "Stool", "Sputum", "Cerebrospinal fluid",
    "Wound swab", "Urethral swab", "Cervical swab", "Other"
]
STANDARD_CULTURE_RESULTS = [
    "Growth - organism identified", "No growth", "Contaminated", "Pending", "Other"
]
STANDARD_DIAGNOSIS_STATUS = ["Suspected", "Probable", "Confirmed", "Unknown"]
STANDARD_INFECTION_ORIGINS = [
    "Community-acquired", "Hospital-acquired", "Healthcare-associated", "Unknown"
]
STANDARD_INFECTION_SYNDROMES = [
    "Pneumonia / Lower respiratory",
    "Upper respiratory",
    "Sepsis / Bloodstream",
    "Meningitis / CNS",
    "Urinary tract",
    "Gastroenteritis / Diarrhoeal",
    "Skin and soft tissue",
    "Undifferentiated fever",
    "Other",
]
STANDARD_OUTCOMES = [
    "Not yet known",
    "Recovered / Improving",
    "Referred / Transferred",
    "Admitted - under treatment",
    "Died",
    "Lost to follow-up",
    "Other",
]
STANDARD_AST_RESULTS = ["Susceptible", "Intermediate", "Resistant", "Not tested"]
STANDARD_AST_METHODS = [
    "Disk diffusion", "Broth microdilution", "E-test", "VITEK", "Other"
]

PATHOGEN_ALIASES: Dict[str, List[str]] = {
    "Escherichia coli": [
        "e. coli", "e coli", "escherichia coli", "ecoli", "eschericia coli", "e.coli"
    ],
    "Klebsiella pneumoniae": [
        "k. pneumoniae", "k pneumoniae", "klebsiella pneumoniae", "klebsiella",
        "kpneumoniae", "k.pneumo", "kleb pneumoniae", "k. pneumoniae subsp. pneumoniae"
    ],
    "Acinetobacter baumannii": [
        "a. baumannii", "a baumannii", "acinetobacter baumannii", "acinetobacter",
        "abaumannii", "a baumanii", "acineto", "acinetobacter calcoaceticus"
    ],
    "Pseudomonas aeruginosa": [
        "p. aeruginosa", "p aeruginosa", "pseudomonas aeruginosa", "pseudomonas",
        "paeruginosa", "pseudomonas aeriginosa", "pseudo", "p.aeruginosa"
    ],
    "Staphylococcus aureus": [
        "s. aureus", "s aureus", "staphylococcus aureus", "staph aureus", "staph",
        "mrsa", "mssa", "saureus", "staphylococcus", "s.aureus"
    ],
    "Streptococcus pneumoniae": [
        "s. pneumoniae", "s pneumoniae", "streptococcus pneumoniae", "strep pneumoniae",
        "pneumococcus", "strep pneumo", "s.pneumoniae"
    ],
    "Salmonella Typhi": [
        "s. typhi", "s typhi", "salmonella typhi", "styphi",
        "salmonella enterica serovar typhi", "s.typhi", "typhoid bacillus"
    ],
    "Salmonella Paratyphi": [
        "s. paratyphi", "s paratyphi", "salmonella paratyphi", "sparatyphi", "s.paratyphi"
    ],
    "Enterococcus species": [
        "enterococcus", "enterococcus faecalis", "enterococcus faecium",
        "enterococcus spp", "enterococcus spp.", "e. faecalis", "e. faecium", "vre"
    ],
    "Shigella species": [
        "shigella", "shigella dysenteriae", "shigella flexneri", "shigella sonnei",
        "shigella boydii", "shigella spp", "shigella spp."
    ],
    "Neisseria gonorrhoeae": [
        "n. gonorrhoeae", "n gonorrhoeae", "neisseria gonorrhoeae", "gonococcus",
        "ngonorrhoeae", "n.gonorrhoeae", "gc"
    ],
}

ANTIBIOTIC_CATALOG: Dict[str, Dict[str, Any]] = {
    "Ampicillin": {
        "class": "Penicillins",
        "aliases": ["ampicillin", "amp", "ampicin", "ampicilin"],
    },
    "Amoxicillin": {
        "class": "Penicillins",
        "aliases": ["amoxicillin", "amox", "amoxyl", "amoxycillin"],
    },
    "Amoxicillin-Clavulanate": {
        "class": "Penicillins",
        "aliases": [
            "amoxicillin-clavulanate", "amoxicillin/clavulanic acid", "amox-clav",
            "amox/clav", "augmentin", "co-amoxiclav", "coamoxiclav", "amoxyclav"
        ],
    },
    "Piperacillin-Tazobactam": {
        "class": "Penicillins",
        "aliases": [
            "piperacillin-tazobactam", "piperacillin/tazobactam", "pip-taz",
            "piptaz", "zosyn", "tazocin", "pip/taz"
        ],
    },
    "Ceftriaxone": {
        "class": "Cephalosporins",
        "aliases": ["ceftriaxone", "rocephin", "ceftriax", "ctr", "ceftriaxone sodium"],
    },
    "Cefotaxime": {
        "class": "Cephalosporins",
        "aliases": ["cefotaxime", "claforan", "ctx", "cefotax"],
    },
    "Ceftazidime": {
        "class": "Cephalosporins",
        "aliases": ["ceftazidime", "fortaz", "caz", "tazidime", "ceftaz"],
    },
    "Cefixime": {
        "class": "Cephalosporins",
        "aliases": ["cefixime", "suprax", "cfm", "zifi", "taxim-o"],
    },
    "Cefepime": {
        "class": "Cephalosporins",
        "aliases": ["cefepime", "maxipime", "fep", "cefepim"],
    },
    "Meropenem": {
        "class": "Carbapenems",
        "aliases": ["meropenem", "merrem", "mem", "meropen"],
    },
    "Imipenem": {
        "class": "Carbapenems",
        "aliases": ["imipenem", "primaxin", "ipm", "imipenem-cilastatin", "imipenem/cilastatin"],
    },
    "Ertapenem": {
        "class": "Carbapenems",
        "aliases": ["ertapenem", "invanz", "etp"],
    },
    "Ciprofloxacin": {
        "class": "Fluoroquinolones",
        "aliases": ["ciprofloxacin", "cipro", "cip", "ciplox", "ciproflox"],
    },
    "Levofloxacin": {
        "class": "Fluoroquinolones",
        "aliases": ["levofloxacin", "levaquin", "levo", "lfx", "levoflox"],
    },
    "Norfloxacin": {
        "class": "Fluoroquinolones",
        "aliases": ["norfloxacin", "noroxin", "nor", "norflox"],
    },
    "Gentamicin": {
        "class": "Aminoglycosides",
        "aliases": ["gentamicin", "garamycin", "gen", "genta", "gentamycin"],
    },
    "Amikacin": {
        "class": "Aminoglycosides",
        "aliases": ["amikacin", "amikin", "ak", "amika"],
    },
    "Tobramycin": {
        "class": "Aminoglycosides",
        "aliases": ["tobramycin", "nebcin", "tob", "tobra"],
    },
    "Azithromycin": {
        "class": "Macrolides",
        "aliases": ["azithromycin", "zithromax", "azm", "azi", "azithro"],
    },
    "Erythromycin": {
        "class": "Macrolides",
        "aliases": ["erythromycin", "erythro", "ery"],
    },
    "Colistin": {
        "class": "Polymyxins",
        "aliases": ["colistin", "polymyxin e", "cst", "colistimethate"],
    },
    "Vancomycin": {
        "class": "Glycopeptides",
        "aliases": ["vancomycin", "vancocin", "van", "vanco"],
    },
    "Teicoplanin": {
        "class": "Glycopeptides",
        "aliases": ["teicoplanin", "targocid", "tec", "teico"],
    },
    "Doxycycline": {
        "class": "Tetracyclines",
        "aliases": ["doxycycline", "doxy", "vibramycin", "dox"],
    },
    "Tetracycline": {
        "class": "Tetracyclines",
        "aliases": ["tetracycline", "tet", "tetra"],
    },
    "Nitrofurantoin": {
        "class": "Other",
        "aliases": ["nitrofurantoin", "macrobid", "macrodantin", "nit", "nitrofur"],
    },
    "Linezolid": {
        "class": "Oxazolidinones",
        "aliases": ["linezolid", "zyvox", "lzd", "lizomac"],
    },
    "Clindamycin": {
        "class": "Lincosamides",
        "aliases": ["clindamycin", "cleocin", "cli", "clinda"],
    },
    "Co-trimoxazole": {
        "class": "Sulfonamides",
        "aliases": [
            "co-trimoxazole", "bactrim", "septra", "trimethoprim-sulfamethoxazole",
            "trimethoprim/sulfamethoxazole", "tmp-smx", "cotrimoxazole", "sxt"
        ],
    },
}

SYMPTOM_ALIASES = {
    "Fever": ["fever", "pyrexia", "high temp", "temperature", "febrile"],
    "Cough": ["cough", "productive cough", "dry cough", "expectoration", "coughing"],
    "Sore Throat": ["sore throat", "throat pain", "pharyngitis"],
    "Shortness of Breath": ["shortness of breath", "dyspnea", "breathlessness", "sob", "difficulty breathing"],
    "Diarrhea": ["diarrhea", "loose stools", "diarrhoea", "watery stools", "frequent stools"],
    "Vomiting": ["vomiting", "emesis", "nausea and vomiting", "throwing up"],
    "Abdominal Cramps": ["abdominal cramps", "stomach pain", "abdominal pain", "cramps", "belly pain"],
    "Dysuria": ["dysuria", "burning urination", "painful urination", "urinary burning"],
    "Headache": ["headache", "cephalalgia", "head pain"],
    "Joint Pain": ["joint pain", "arthralgia", "body ache", "myalgia"],
    "Skin Rash": ["skin rash", "rash", "erythema", "lesions", "petechiae"],
    "Fatigue": ["fatigue", "tiredness", "lethargy", "weakness", "malaise"],
    "Chills": ["chills", "rigors", "shivering"],
    "Nausea": ["nausea", "queasiness"],
}


def _clean_str(text: Optional[str]) -> str:
    if not text:
        return ""
    return re.sub(r"\s+", " ", text.strip().lower())


def age_to_age_group(age: int) -> str:
    if age < 5:
        return "0-4"
    if age < 15:
        return "5-14"
    if age < 25:
        return "15-24"
    if age < 45:
        return "25-44"
    if age < 65:
        return "45-64"
    return "65+"


def normalize_sex(sex_str: Optional[str]) -> Tuple[str, float]:
    cleaned = _clean_str(sex_str)
    if not cleaned:
        return "Other", 0.0
    if cleaned in ["m", "male", "man", "boy"]:
        return "Male", 1.0
    if cleaned in ["f", "female", "woman", "girl"]:
        return "Female", 1.0
    if cleaned in ["other", "transgender", "non-binary"]:
        return "Other", 1.0
    return "Other", 0.4


def normalize_district(district_str: Optional[str]) -> Tuple[str, float]:
    cleaned = _clean_str(district_str)
    if not cleaned:
        return "Pune", 0.0
    for standard in STANDARD_DISTRICTS:
        if cleaned == standard.lower():
            return standard, 1.0
        if cleaned in standard.lower() or standard.lower() in cleaned:
            return standard, 0.85
    # Capitalize as fallback
    return district_str.strip().title(), 0.6


def normalize_pathogen(raw_pathogen: Optional[str]) -> Tuple[str, Optional[str], float]:
    cleaned = _clean_str(raw_pathogen)
    if not cleaned:
        return "Other", None, 0.0

    for standard, aliases in PATHOGEN_ALIASES.items():
        if cleaned == standard.lower():
            return standard, None, 1.0
        for alias in aliases:
            if cleaned == alias or alias in cleaned:
                return standard, None, 0.95

    return "Other", raw_pathogen.strip(), 0.5


def normalize_antibiotic(raw_drug: Optional[str]) -> Tuple[Optional[str], Optional[str], float]:
    cleaned = _clean_str(raw_drug)
    if not cleaned:
        return None, None, 0.0

    for standard, info in ANTIBIOTIC_CATALOG.items():
        if cleaned == standard.lower():
            return standard, info["class"], 1.0
        for alias in info["aliases"]:
            if cleaned == alias or alias in cleaned:
                return standard, info["class"], 0.95

    return raw_drug.strip(), "Other", 0.4


def normalize_ast_result(raw_sir: Optional[str]) -> Tuple[str, float]:
    cleaned = _clean_str(raw_sir)
    if not cleaned:
        return "Not tested", 0.0

    if cleaned in ["r", "res", "resistant", "resistance"]:
        return "Resistant", 1.0
    if cleaned in ["s", "sens", "sus", "sensitive", "susceptible", "susceptibility"]:
        return "Susceptible", 1.0
    if cleaned in ["i", "int", "intermediate", "moderately susceptible"]:
        return "Intermediate", 1.0
    if cleaned in ["nt", "not tested", "none", "na", "n/a", "-"]:
        return "Not tested", 1.0

    return "Not tested", 0.3


def normalize_specimen(raw_specimen: Optional[str]) -> Tuple[str, Optional[str], float]:
    cleaned = _clean_str(raw_specimen)
    if not cleaned:
        return "Blood", None, 0.0

    specimen_map = {
        "Blood": ["blood", "whole blood", "serum", "plasma", "blood culture", "hemoculture"],
        "Urine": ["urine", "midstream urine", "msu", "catheter urine", "clean catch"],
        "Stool": ["stool", "feces", "faeces", "rectal swab"],
        "Sputum": ["sputum", "et secretions", "tracheal aspirate", "bal", "bronchoalveolar"],
        "Cerebrospinal fluid": ["cerebrospinal fluid", "csf", "lumbar puncture", "spinal fluid"],
        "Wound swab": ["wound swab", "wound", "pus", "abscess", "tissue", "ulcer swab"],
        "Urethral swab": ["urethral swab", "urethra", "urethral discharge"],
        "Cervical swab": ["cervical swab", "cervix", "endocervical", "high vaginal swab", "hvs"],
    }

    for standard, aliases in specimen_map.items():
        for alias in aliases:
            if cleaned == alias or alias in cleaned:
                return standard, None, 0.95

    return "Other", raw_specimen.strip(), 0.5


def normalize_syndrome(raw_syndrome: Optional[str]) -> Tuple[str, Optional[str], float]:
    cleaned = _clean_str(raw_syndrome)
    if not cleaned:
        return "Undifferentiated fever", None, 0.0

    syndrome_map = {
        "Pneumonia / Lower respiratory": ["pneumonia", "lrti", "lower respiratory", "chest infection", "bronchitis", "copd exacerbation"],
        "Upper respiratory": ["urti", "upper respiratory", "pharyngitis", "sinusitis", "cold", "flu"],
        "Sepsis / Bloodstream": ["sepsis", "bacteremia", "bloodstream", "septicemia", "shock"],
        "Meningitis / CNS": ["meningitis", "cns infection", "encephalitis"],
        "Urinary tract": ["urinary tract", "uti", "pyelonephritis", "cystitis"],
        "Gastroenteritis / Diarrhoeal": ["gastroenteritis", "diarrhea", "food poisoning", "dysentery", "acute gastroenteritis", "age"],
        "Skin and soft tissue": ["skin", "soft tissue", "ssti", "cellulitis", "abscess", "wound infection"],
        "Undifferentiated fever": ["fever", "pyrexia of unknown origin", "puo", "fever without source", "undifferentiated fever"],
    }

    for standard, aliases in syndrome_map.items():
        for alias in aliases:
            if cleaned == alias or alias in cleaned:
                return standard, None, 0.95

    return "Other", raw_syndrome.strip(), 0.5


def normalize_origin(raw_origin: Optional[str]) -> Tuple[str, float]:
    cleaned = _clean_str(raw_origin)
    if not cleaned:
        return "Community-acquired", 0.5

    if "hospital" in cleaned or "nosocomial" in cleaned or "hai" in cleaned:
        return "Hospital-acquired", 1.0
    if "health" in cleaned or "hcai" in cleaned or "clinic" in cleaned or "nursing home" in cleaned:
        return "Healthcare-associated", 0.95
    if "communit" in cleaned or "home" in cleaned:
        return "Community-acquired", 0.95

    return "Unknown", 0.5


def normalize_symptoms(raw_symptoms: Any) -> List[str]:
    if not raw_symptoms:
        return []

    tokens: List[str] = []
    if isinstance(raw_symptoms, list):
        tokens = [str(item) for item in raw_symptoms]
    elif isinstance(raw_symptoms, str):
        tokens = [part.strip() for part in re.split(r"[,;\n\r]+", raw_symptoms) if part.strip()]

    matched_symptoms = set()
    for token in tokens:
        cleaned_token = _clean_str(token)
        for std_symptom, aliases in SYMPTOM_ALIASES.items():
            if cleaned_token == std_symptom.lower():
                matched_symptoms.add(std_symptom)
                break
            for alias in aliases:
                if alias in cleaned_token:
                    matched_symptoms.add(std_symptom)
                    break

    return sorted(list(matched_symptoms))
