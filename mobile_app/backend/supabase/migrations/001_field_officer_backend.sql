CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS "User" (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role VARCHAR(100) NOT NULL,
    name VARCHAR(255),
    assigned_district VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS Division (
    division_id SERIAL PRIMARY KEY,
    division_name VARCHAR(255) UNIQUE NOT NULL,
    district VARCHAR(255),
    latitude NUMERIC,
    longitude NUMERIC,
    province VARCHAR(255),
    division_population INT
);

CREATE TYPE IF NOT EXISTS incident_severity AS ENUM ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL');
CREATE TYPE IF NOT EXISTS incident_status AS ENUM ('ACTIVE', 'UNDER_RESPONSE', 'RESOLVED', 'CLOSED');
CREATE TYPE IF NOT EXISTS disaster_type AS ENUM ('FLOOD', 'LANDSLIDE', 'FIRE', 'CYCLONE', 'TSUNAMI', 'DROUGHT', 'EARTHQUAKE');
CREATE TYPE IF NOT EXISTS alert_type AS ENUM ('WEATHER', 'RESOURCE', 'EVACUATION', 'HEALTH', 'SECURITY');

CREATE TABLE IF NOT EXISTS ConfirmedIncident (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    disasterType disaster_type NOT NULL,
    district VARCHAR(255) NOT NULL,
    severity incident_severity NOT NULL,
    status incident_status NOT NULL,
    latitude FLOAT8 NOT NULL,
    longitude FLOAT8 NOT NULL,
    description TEXT,
    publicVisibility BOOLEAN NOT NULL DEFAULT TRUE,
    affectedPeople INT NOT NULL,
    createdAt TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updatedAt TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ActiveIncident (
    incident_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    severity VARCHAR(50) NOT NULL,
    affected_population INT,
    status VARCHAR(50) NOT NULL,
    latitude NUMERIC,
    longitude NUMERIC,
    division_id INT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    closed_at TIMESTAMPTZ,
    CONSTRAINT fk_active_incident_division FOREIGN KEY (division_id) REFERENCES Division(division_id)
);

CREATE TABLE IF NOT EXISTS PersonnelAssignment (
    assignment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_id UUID NOT NULL,
    user_id UUID NOT NULL,
    assigned_role VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL,
    assigned_by UUID,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    released_at TIMESTAMPTZ,
    notes TEXT,
    CONSTRAINT fk_assignment_incident FOREIGN KEY (incident_id) REFERENCES ConfirmedIncident(id)
);

CREATE TABLE IF NOT EXISTS PublicAlert (
    alert_id SERIAL PRIMARY KEY,
    incident_id UUID,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    severity_level VARCHAR(50),
    status VARCHAR(50) NOT NULL,
    issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS Alert (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type alert_type NOT NULL,
    severity incident_severity NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    district VARCHAR(255) NOT NULL,
    isPublic BOOLEAN NOT NULL DEFAULT FALSE,
    isActive BOOLEAN NOT NULL DEFAULT TRUE,
    source VARCHAR(255),
    createdAt TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expiresAt TIMESTAMPTZ,
    incidentId UUID
);

CREATE TABLE IF NOT EXISTS Shelter (
    shelter_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(100),
    division_id INT,
    latitude NUMERIC,
    longitude NUMERIC,
    max_capacity INT NOT NULL,
    current_occupancy INT NOT NULL DEFAULT 0,
    status VARCHAR(50) NOT NULL,
    contact_person VARCHAR(255),
    contact_phone VARCHAR(50),
    updated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS ResourceRequest (
    request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_id UUID NOT NULL,
    requested_by UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status VARCHAR(50) NOT NULL,
    items JSONB NOT NULL,
    notes TEXT,
    reviewed_by UUID,
    reviewed_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS ResourcePlan (
    plan_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_id UUID,
    requested_by UUID,
    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status VARCHAR(50) NOT NULL,
    plan_json JSONB NOT NULL,
    divisions_analyzed INT,
    approved_by UUID,
    approved_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS LogisticsDeployment (
    deployment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    resource_request_id UUID,
    resource_plan_id UUID,
    user_id UUID NOT NULL,
    dispatched_by UUID,
    dispatched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status VARCHAR(50) NOT NULL,
    delivery_notes TEXT,
    completed_at TIMESTAMPTZ,
    items_dispatched JSONB,
    incident_id UUID
);

CREATE TABLE IF NOT EXISTS IncidentReport (
    report_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_id UUID NOT NULL,
    assigned_to UUID NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) NOT NULL,
    acknowledged BOOLEAN DEFAULT FALSE,
    acknowledged_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS Notification (
    notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(100),
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_personnel_assignment_user_status ON PersonnelAssignment (user_id, status);
CREATE INDEX IF NOT EXISTS idx_personnel_assignment_incident ON PersonnelAssignment (incident_id);
CREATE INDEX IF NOT EXISTS idx_alert_active_public ON Alert (isActive, isPublic, district, createdAt DESC);
CREATE INDEX IF NOT EXISTS idx_public_alert_incident ON PublicAlert (incident_id, issued_at DESC);
CREATE INDEX IF NOT EXISTS idx_shelter_division_status ON Shelter (division_id, status);
CREATE INDEX IF NOT EXISTS idx_resource_request_user_created ON ResourceRequest (requested_by, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_resource_request_incident_status ON ResourceRequest (incident_id, status);
CREATE INDEX IF NOT EXISTS idx_logistics_deployment_user_status ON LogisticsDeployment (user_id, status, dispatched_at DESC);
CREATE INDEX IF NOT EXISTS idx_incident_report_assigned_status ON IncidentReport (assigned_to, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notification_user_read_created ON Notification (user_id, is_read, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_confirmed_incident_status_severity ON ConfirmedIncident (status, severity, createdAt DESC);
CREATE INDEX IF NOT EXISTS idx_division_name_district ON Division (division_name, district);
