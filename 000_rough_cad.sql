CREATE DATABASE cad_dispatch;

CREATE EXTENSION "uuid-ossp";

------------------------------------
-- Agencies
------------------------------------
CREATE TABLE agencies (
	agency_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
	name VARCHAR(100) NOT NULL,
	agency_type VARCHAR(20) NOT NULL, -- Police, Fire, EMS, Vol
	phone_number VARCHAR(20), -- 10 dig plus room for ext
	fax_number VARCHAR(20), -- 10 dig plus room for ext
	foil_rep VARCHAR(100), -- name of foil representitive for agency
	dept_head VARCHAR(100), -- name of department head
	named_rank VARCHAR(20), -- rank like major, sheriff, chief
	website VARCHAR(200), -- example www.somecountySheriff.gov
	updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	-- updated_by from users table
);


------------------------------------
-- Users / Dispatchers
------------------------------------

CREATE TABLE users (
	user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
	agency_id UUID REFERENCES agencies(agency_id),
	username VARCHAR(50) UNIQUE NOT NULL,
	password_hash TEXT NOT NULL,
	first_name VARCHAR(50),
	last_name VARCHAR(50),
	role VARCHAR(50), -- Dispatcher, Supervisor, Adin, Audit
	active BOOLEAN DEFAULT TRUE,
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-----------------------------------
-- Stations
-----------------------------------
CREATE TABLE stations (
    station_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agency_id UUID REFERENCES agencies(agency_id),
    name VARCHAR(100),
    address TEXT
);


--------------------------------------------------
-- Units
--------------------------------------------------
CREATE TABLE units (
    unit_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agency_id UUID REFERENCES agencies(agency_id),
    station_id UUID REFERENCES stations(station_id),
    unit_number VARCHAR(20) UNIQUE NOT NULL,
    unit_type VARCHAR(30), -- Patrol, Engine, Medic, Rescue
    radio_id VARCHAR(30),
    status VARCHAR(20) DEFAULT 'Available',
    gps_lat NUMERIC(10,7),
    gps_lon NUMERIC(10,7),
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

--------------------------------------------------
-- Personnel
--------------------------------------------------
CREATE TABLE personnel (
    person_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agency_id UUID REFERENCES agencies(agency_id),
    badge_number VARCHAR(20),
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    rank VARCHAR(30),
    phone VARCHAR(20),
    active BOOLEAN DEFAULT TRUE
);

--------------------------------------------------
-- Unit Assignments
--------------------------------------------------
CREATE TABLE unit_assignments (
    assignment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    unit_id UUID REFERENCES units(unit_id),
    person_id UUID REFERENCES personnel(person_id),
    start_time TIMESTAMP,
    end_time TIMESTAMP
);

--------------------------------------------------
-- Call Types
--------------------------------------------------
CREATE TABLE call_types (
    call_type_id SERIAL PRIMARY KEY,
    code VARCHAR(20),
    description VARCHAR(200),
    priority SMALLINT
);

--------------------------------------------------
-- Locations
--------------------------------------------------
CREATE TABLE locations (
    location_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(50),
    zip VARCHAR(15),
    latitude NUMERIC(10,7),
    longitude NUMERIC(10,7)
);

--------------------------------------------------
-- Incidents
--------------------------------------------------
CREATE TABLE incidents (
    incident_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    incident_number VARCHAR(30) UNIQUE,
    call_type_id INTEGER REFERENCES call_types(call_type_id),
    location_id UUID REFERENCES locations(location_id),
    caller_name VARCHAR(100),
    caller_phone VARCHAR(20),
    narrative TEXT,
    priority SMALLINT,
    status VARCHAR(20) DEFAULT 'Open',
    created_by UUID REFERENCES users(user_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    closed_at TIMESTAMP
);

--------------------------------------------------
-- Dispatch Log
--------------------------------------------------
CREATE TABLE dispatch_log (
    log_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    incident_id UUID REFERENCES incidents(incident_id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(user_id),
    event_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    event_type VARCHAR(30),
    notes TEXT
);

--------------------------------------------------
-- Unit Dispatch
--------------------------------------------------
CREATE TABLE incident_units (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    incident_id UUID REFERENCES incidents(incident_id) ON DELETE CASCADE,
    unit_id UUID REFERENCES units(unit_id),
    dispatched_at TIMESTAMP,
    enroute_at TIMESTAMP,
    arrived_at TIMESTAMP,
    cleared_at TIMESTAMP,
    disposition VARCHAR(50)
);

--------------------------------------------------
-- Status History
--------------------------------------------------
CREATE TABLE unit_status_history (
    history_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    unit_id UUID REFERENCES units(unit_id),
    status VARCHAR(30),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

--------------------------------------------------
-- Notes
--------------------------------------------------
CREATE TABLE incident_notes (
    note_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    incident_id UUID REFERENCES incidents(incident_id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(user_id),
    note TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

--------------------------------------------------
-- Attachments
--------------------------------------------------
CREATE TABLE attachments (
    attachment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    incident_id UUID REFERENCES incidents(incident_id) ON DELETE CASCADE,
    filename VARCHAR(255),
    storage_path TEXT,
    uploaded_by UUID REFERENCES users(user_id),
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

--------------------------------------------------
-- Indexes
--------------------------------------------------
CREATE INDEX idx_incident_status ON incidents(status);
CREATE INDEX idx_incident_created ON incidents(created_at);
CREATE INDEX idx_unit_status ON units(status);
CREATE INDEX idx_dispatch_incident ON dispatch_log(incident_id);
CREATE INDEX idx_incident_units ON incident_units(incident_id);
CREATE INDEX idx_location_coords ON locations(latitude, longitude);
