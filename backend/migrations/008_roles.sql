-- Role-based access.
--
-- master.doctors is now the credential table for all clinical staff, not only
-- doctors. Renaming it would touch every foreign key and query in the codebase
-- for no functional gain, so the table keeps its name and gains a role.
--
-- DEFAULT 'doctor' means every existing account keeps working with no backfill.
ALTER TABLE master.doctors
    ADD COLUMN IF NOT EXISTS role VARCHAR NOT NULL DEFAULT 'doctor';

ALTER TABLE master.doctors
    DROP CONSTRAINT IF EXISTS ck_doctors_role;
ALTER TABLE master.doctors
    ADD CONSTRAINT ck_doctors_role
    CHECK (role IN ('doctor', 'lab', 'analyst', 'admin'));

CREATE INDEX IF NOT EXISTS ix_doctors_role ON master.doctors (role);
