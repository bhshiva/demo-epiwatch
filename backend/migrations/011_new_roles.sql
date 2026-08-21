-- Two new roles beyond doctor/lab:
--   health_authority -- read-only, sees all-facility surveillance stats.
--   admin            -- reviews facility/clinic access applications and
--                        provisions accounts on approval. Already existed
--                        as a role value (migration 008) but had no real
--                        purpose beyond a lab-endpoint access grant, which
--                        migration 009/this pass's app-layer change removed
--                        (lab.py now gates on require_role("lab") only).
--
-- Neither role is tied to one facility -- a health authority views every
-- facility's data, and admin approves accounts before any facility-scoped
-- work exists for them. facility_id therefore has to become nullable; every
-- existing doctor/lab row already has one and is untouched by this change.

ALTER TABLE master.doctors ALTER COLUMN facility_id DROP NOT NULL;

ALTER TABLE master.doctors DROP CONSTRAINT IF EXISTS ck_doctors_role;
ALTER TABLE master.doctors ADD CONSTRAINT ck_doctors_role
    CHECK (role IN ('doctor', 'lab', 'analyst', 'admin', 'health_authority'));

-- Accounts provisioned by admin approval get a generated one-time password
-- (there is no email/notification infrastructure to do a reset-link flow
-- yet); this flag forces a change on first login rather than leaving that
-- password live indefinitely.
ALTER TABLE master.doctors ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN NOT NULL DEFAULT false;

-- Facility/clinic access requests. Submitted by an applicant with no
-- account yet (an unauthenticated endpoint), reviewed by admin.
CREATE TABLE IF NOT EXISTS master.facility_applications (
    application_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    facility_name VARCHAR NOT NULL,
    facility_type VARCHAR NOT NULL CHECK (facility_type IN ('Hospital', 'Clinic', 'Dispensary')),
    district VARCHAR NOT NULL,
    state VARCHAR NOT NULL,

    contact_name VARCHAR NOT NULL,
    contact_email VARCHAR NOT NULL,
    contact_phone VARCHAR,
    license_no VARCHAR,

    -- The role the resulting account should get once approved.
    requested_role VARCHAR NOT NULL CHECK (requested_role IN ('doctor', 'lab')),

    status VARCHAR NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    reviewed_by UUID REFERENCES master.doctors(doctor_id),
    reviewed_at TIMESTAMP,
    rejection_reason TEXT,

    -- Set on approval, so the application row keeps a durable link to what
    -- it actually provisioned.
    created_facility_id UUID REFERENCES master.facilities(facility_id),
    created_doctor_id UUID REFERENCES master.doctors(doctor_id),

    submitted_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_facility_applications_status
    ON master.facility_applications(status);
