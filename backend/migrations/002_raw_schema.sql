CREATE SCHEMA IF NOT EXISTS raw;

CREATE TABLE raw.patient_reports (
    report_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES master.patients(patient_id),
    doctor_id UUID NOT NULL REFERENCES master.doctors(doctor_id),
    facility_id UUID NOT NULL REFERENCES master.facilities(facility_id),
    report_date DATE NOT NULL,
    complaints TEXT,
    medical_history TEXT,
    symptoms JSONB,
    diagnosis VARCHAR,
    diagnosis_status VARCHAR CHECK (diagnosis_status IN ('Suspected', 'Probable', 'Confirmed')),
    treatment TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE raw.prescriptions (
    prescription_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id UUID NOT NULL REFERENCES raw.patient_reports(report_id),
    drug_name VARCHAR NOT NULL,
    dosage VARCHAR,
    duration VARCHAR,
    prescribed_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE raw.lab_results (
    lab_result_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id UUID NOT NULL REFERENCES raw.patient_reports(report_id),
    facility_id UUID NOT NULL REFERENCES master.facilities(facility_id),
    test_date DATE,
    specimen_type VARCHAR,
    pathogen VARCHAR,
    antibiotic VARCHAR,
    ast_result VARCHAR CHECK (ast_result IN ('Resistant', 'Susceptible', 'Intermediate')),
    created_at TIMESTAMP NOT NULL DEFAULT now()
);
