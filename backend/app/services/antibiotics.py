"""
Antibiotic reference data.

Class matters more than drug name for surveillance: MDR/XDR is defined by the
number of resistant drug *classes*, and co-resistance is far stronger within a
class than across one. Mirrors ClinicalCatalog.AntibioticToClass on the client
so both sides label the same drug identically.
"""

ANTIBIOTIC_CLASS: dict[str, str] = {
    "Ciprofloxacin": "Fluoroquinolones",
    "Levofloxacin": "Fluoroquinolones",
    "Norfloxacin": "Fluoroquinolones",
    "Ofloxacin": "Fluoroquinolones",
    "Ceftriaxone": "Cephalosporins",
    "Cefotaxime": "Cephalosporins",
    "Ceftazidime": "Cephalosporins",
    "Cefixime": "Cephalosporins",
    "Cefepime": "Cephalosporins",
    "Meropenem": "Carbapenems",
    "Imipenem": "Carbapenems",
    "Ertapenem": "Carbapenems",
    "Amoxicillin": "Penicillins",
    "Amoxicillin-Clavulanate": "Penicillins",
    "Piperacillin-Tazobactam": "Penicillins",
    "Ampicillin": "Penicillins",
    "Gentamicin": "Aminoglycosides",
    "Amikacin": "Aminoglycosides",
    "Tobramycin": "Aminoglycosides",
    "Azithromycin": "Macrolides",
    "Erythromycin": "Macrolides",
    "Clarithromycin": "Macrolides",
    "Vancomycin": "Glycopeptides",
    "Teicoplanin": "Glycopeptides",
    "Doxycycline": "Tetracyclines",
    "Tetracycline": "Tetracyclines",
    "Co-trimoxazole": "Sulfonamides",
    "Colistin": "Polymyxins",
    "Polymyxin B": "Polymyxins",
    "Nitrofurantoin": "Nitrofurans",
    "Linezolid": "Oxazolidinones",
    "Clindamycin": "Lincosamides",
}

# Reserved for when first-line options fail. The empirical-therapy advisor
# penalises these so it does not casually recommend an agent whose use drives
# the next wave of resistance.
LAST_LINE_CLASSES = {"Carbapenems", "Polymyxins", "Glycopeptides", "Oxazolidinones"}

# Preferred when they cover the organism, to limit selection pressure.
NARROW_SPECTRUM = {"Nitrofurantoin", "Penicillin", "Ampicillin", "Co-trimoxazole"}


def antibiotic_class(name: str | None) -> str | None:
    if not name:
        return None
    return ANTIBIOTIC_CLASS.get(name.strip())


def is_last_line(name: str | None) -> bool:
    return antibiotic_class(name) in LAST_LINE_CLASSES
