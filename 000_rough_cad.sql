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


