/// Standard clinical vocabularies for the report form.
///
/// Using fixed lists rather than free text is what makes cross-facility
/// aggregation possible - "E. coli", "E.coli" and "Escherichia coli" typed
/// freehand cannot be counted together.
///
/// Sources:
///  - Specimen types, AST categories and age strata follow WHO GLASS
///    (Global Antimicrobial Resistance and Use Surveillance System).
///  - Priority pathogens follow the ICMR-AMRSN panel, India's national AMR
///    surveillance network, so the data lines up with national reporting.
abstract final class ClinicalCatalog {
  static const specimenTypes = [
    'Blood',
    'Urine',
    'Stool',
    'Sputum',
    'Cerebrospinal fluid',
    'Wound swab',
    'Urethral swab',
    'Cervical swab',
    'Other',
  ];

  static const pathogens = [
    'Escherichia coli',
    'Klebsiella pneumoniae',
    'Acinetobacter baumannii',
    'Pseudomonas aeruginosa',
    'Staphylococcus aureus',
    'Streptococcus pneumoniae',
    'Salmonella Typhi',
    'Salmonella Paratyphi',
    'Enterococcus species',
    'Shigella species',
    'Neisseria gonorrhoeae',
    'Other',
  ];

  static const antibioticClasses = [
    'Fluoroquinolones',
    'Cephalosporins',
    'Carbapenems',
    'Penicillins',
    'Aminoglycosides',
    'Macrolides',
    'Glycopeptides',
    'Tetracyclines',
    'Sulfonamides',
    'Polymyxins',
    'Nitrofurans',
    'Oxazolidinones',
    'Lincosamides',
    'Other',
  ];

  static const antibioticToClass = <String, String>{
    'Ciprofloxacin': 'Fluoroquinolones',
    'Levofloxacin': 'Fluoroquinolones',
    'Norfloxacin': 'Fluoroquinolones',
    'Ceftriaxone': 'Cephalosporins',
    'Cefotaxime': 'Cephalosporins',
    'Ceftazidime': 'Cephalosporins',
    'Cefixime': 'Cephalosporins',
    'Cefepime': 'Cephalosporins',
    'Meropenem': 'Carbapenems',
    'Imipenem': 'Carbapenems',
    'Ertapenem': 'Carbapenems',
    'Amoxicillin': 'Penicillins',
    'Amoxicillin-Clavulanate': 'Penicillins',
    'Piperacillin-Tazobactam': 'Penicillins',
    'Ampicillin': 'Penicillins',
    'Gentamicin': 'Aminoglycosides',
    'Amikacin': 'Aminoglycosides',
    'Tobramycin': 'Aminoglycosides',
    'Azithromycin': 'Macrolides',
    'Erythromycin': 'Macrolides',
    'Vancomycin': 'Glycopeptides',
    'Teicoplanin': 'Glycopeptides',
    'Doxycycline': 'Tetracyclines',
    'Tetracycline': 'Tetracyclines',
    'Nitrofurantoin': 'Nitrofurans',
    'Linezolid': 'Oxazolidinones',
    'Clindamycin': 'Lincosamides',
    'Co-trimoxazole': 'Sulfonamides',
    'Colistin': 'Polymyxins',
  };

  static List<String> get antibiotics =>
      antibioticToClass.keys.toList()..sort();

  /// The class for a drug name, matched case-insensitively since a lab or
  /// clinician may type "meropenem" as readily as "Meropenem".
  static String? classFor(String antibiotic) {
    final match = antibioticToClass.entries.where(
        (e) => e.key.toLowerCase() == antibiotic.trim().toLowerCase());
    return match.isEmpty ? null : match.first.value;
  }

  static const astResults = [
    'Susceptible',
    'Intermediate',
    'Resistant',
    // An organism identified without a susceptibility panel run is a
    // different fact from a missing record, so it needs its own value.
    'Not tested',
  ];

  static const ageGroups = ['0-4', '5-14', '15-24', '25-44', '45-64', '65+'];

  /// Maps an exact age onto the GLASS band used for aggregation, so the
  /// clinician records a real age and the surveillance key stays consistent.
  static String ageGroupFor(int age) {
    if (age < 0) return '';
    if (age <= 4) return '0-4';
    if (age <= 14) return '5-14';
    if (age <= 24) return '15-24';
    if (age <= 44) return '25-44';
    if (age <= 64) return '45-64';
    return '65+';
  }

  static const sexes = ['Male', 'Female', 'Other'];

  static const diagnosisStatuses = ['Suspected', 'Probable', 'Confirmed', 'Unknown'];

  /// ACORN infection origin. GLASS stratifies by this too; it separates
  /// community outbreaks from in-facility transmission.
  static const infectionOrigins = [
    'Community-acquired',
    'Hospital-acquired',
    'Healthcare-associated',
    'Unknown',
  ];

  /// ACORN syndromic classification. Grouping by presentation rather than by
  /// free-text diagnosis is what makes trend detection reliable across
  /// facilities that word diagnoses differently.
  static const infectionSyndromes = [
    'Pneumonia / Lower respiratory',
    'Upper respiratory',
    'Sepsis / Bloodstream',
    'Meningitis / CNS',
    'Urinary tract',
    'Gastroenteritis / Diarrhoeal',
    'Skin and soft tissue',
    'Undifferentiated fever',
    'Other',
  ];

  /// ACORN patient outcome. ACORN captures this at discharge and day 28,
  /// which a point-of-care report cannot know yet - hence the explicit
  /// "Not yet known" default rather than forcing a premature answer.
  static const patientOutcomes = [
    'Not yet known',
    'Recovered / Improving',
    'Referred / Transferred',
    'Admitted - under treatment',
    'Died',
    'Lost to follow-up',
    'Other',
  ];

  static const cultureResults = [
    'No growth',
    'Growth - organism identified',
    'Contaminated',
    'Pending',
    'Other',
  ];

  static const commonSymptoms = [
    'Fever',
    'Cough',
    'Sore Throat',
    'Shortness of Breath',
    'Diarrhea',
    'Vomiting',
    'Abdominal Cramps',
    'Dysuria',
    'Headache',
    'Joint Pain',
    'Skin Rash',
    'Fatigue',
    'Chills',
    'Nausea',
  ];

  static const astMethods = ['Disk diffusion', 'Broth microdilution', 'E-test', 'VITEK', 'Other'];

  static const micOperators = ['=', '<=', '>=', '<', '>'];

  static const isolateStatuses = ['pending', 'preliminary', 'final'];

  /// Routine Gram-negative susceptibility panel, so a technician loads a
  /// standard set rather than adding twelve drugs by hand.
  static const gramNegativePanel = [
    'Ampicillin',
    'Amoxicillin-Clavulanate',
    'Piperacillin-Tazobactam',
    'Ceftriaxone',
    'Ceftazidime',
    'Cefepime',
    'Meropenem',
    'Imipenem',
    'Ciprofloxacin',
    'Gentamicin',
    'Amikacin',
    'Co-trimoxazole',
  ];

  static const districts = [
    'Mumbai',
    'Pune',
    'Nagpur',
    'Nashik',
    'Thane',
    'Delhi',
    'Bengaluru',
    'Chennai',
    'Hyderabad',
    'Kolkata',
    'Ahmedabad',
    'Jaipur',
    'Lucknow',
  ];
}
