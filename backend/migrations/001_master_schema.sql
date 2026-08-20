CREATE SCHEMA IF NOT EXISTS master;

CREATE TABLE master.facilities (
    facility_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR NOT NULL,
    type VARCHAR NOT NULL CHECK (type IN ('Hospital', 'Clinic', 'Dispensary')),
    district VARCHAR NOT NULL,
    state VARCHAR NOT NULL,
    latitude DECIMAL,
    longitude DECIMAL
);

CREATE TABLE master.doctors (
    doctor_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR NOT NULL,
    specialization VARCHAR,
    facility_id UUID NOT NULL REFERENCES master.facilities(facility_id),
    license_no VARCHAR,
    email VARCHAR NOT NULL UNIQUE,
    password_hash VARCHAR NOT NULL,
    failed_login_count INTEGER NOT NULL DEFAULT 0,
    locked_until TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE master.patients (
    patient_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    anonymous_id UUID NOT NULL DEFAULT gen_random_uuid(),
    age_group VARCHAR NOT NULL,
    sex VARCHAR NOT NULL,
    district VARCHAR NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);
