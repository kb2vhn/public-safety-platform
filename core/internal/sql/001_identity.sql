-- Schema Blueprintsql
-- This is implementing the Two-Person Concept. This is just the SQL portion the *.go still needs to be further thought out and tested. This gives a begining stage to the SQL.
-- Enable standard UUID generation for secure, non-sequential primary keys
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Define modern public safety platform roles
CREATE TYPE platform_role AS ENUM (
    'SYS_ADMIN',       -- Manages structural changes and configurations only. Cannot write operational logs.
    'DEPT_HEAD_RO',    -- Department Heads / Directors. Read-only to CAD/RMS. Can modify shift rosters.
    'HR_AUDITOR',      -- Human Resources. Acts as mandatory secondary co-signer for administrative privileges.
    'SHIFT_SUPERVISOR',-- Shift Supervisor. Must actively sign off on a dispatcher/officer's live shift activation.
    'DISPATCHER',      -- 911 Communications Personnel.
    'PATROL_OFFICER'   -- Field personnel (Deputies, Fire, EMS).
);

-- Define strict operational and account states
CREATE TYPE account_status AS ENUM ('ACTIVE', 'SUSPENDED', 'LOCKED_OUT', 'INACTIVE');
CREATE TYPE approval_stage AS ENUM ('PROPOSED', 'HR_CO_SIGNED', 'ACTIVATED', 'REJECTED', 'REVOKED');

-- 1. CORE AGENCIES
CREATE TABLE agencies (
    agency_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agency_name VARCHAR(100) NOT NULL UNIQUE,
    ori_number VARCHAR(9) NOT NULL UNIQUE, -- Originating Agency Identifier for state/federal CJIS compliance
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. CORE USERS (Tied directly to Active Directory usernames via LDAPS)
CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agency_id UUID NOT NULL REFERENCES agencies(agency_id),
    username VARCHAR(50) NOT NULL UNIQUE, -- Must match the sAMAccountName in AD
    email VARCHAR(100) NOT NULL UNIQUE,
    account_state account_status NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. THE TWO-MAN PRIVILEGE LEDGER (No single person can grant an admin role)
CREATE TABLE privilege_authorization_ledger (
    request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    target_user_id UUID NOT NULL REFERENCES users(user_id),
    requested_role platform_role NOT NULL,
    status approval_stage NOT NULL DEFAULT 'PROPOSED',
    
    -- Stage 1: Proposed by high-level IT or Senior Admin
    initiated_by_admin_id UUID NOT NULL REFERENCES users(user_id),
    initiated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    initiation_reason TEXT NOT NULL,
    
    -- Stage 2: Co-signed by HR (Mandatory secondary authority)
    hr_approver_id UUID REFERENCES users(user_id),
    hr_co_signed_at TIMESTAMPTZ,
    
    -- Stage 3: Operational Activation by Department Head / Director
    dept_head_approver_id UUID REFERENCES users(user_id),
    activated_at TIMESTAMPTZ,
    
    -- Revocation Tracking (IT / Leadership can trigger this instantly unilaterally)
    revoked_by_id UUID REFERENCES users(user_id),
    revoked_at TIMESTAMPTZ,
    
    CONSTRAINT chk_hr_signoff CHECK (hr_approver_id IS NULL OR hr_co_signed_at IS NOT NULL),
    CONSTRAINT chk_dept_signoff CHECK (dept_head_approver_id IS NULL OR activated_at IS NOT NULL)
);

-- 4. HARDWARE AFFINITY GATE (Validates 802.1X Machine Certs and Network Subnets)
CREATE TABLE administrative_hardware_gates (
    gate_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id),
    enforced_role platform_role NOT NULL,
    
    -- Must strictly match the Common Name (CN) inside the workstation's 802.1X machine certificate
    allowed_machine_cert_cn VARCHAR(100) NOT NULL, 
    
    -- Enforces Layer 2 subnet boundaries (e.g., Jumpbox isolated subnets like 10.10.90.0/24)
    allowed_network_subnet INET NOT NULL, 
    
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, enforced_role, allowed_machine_cert_cn)
);

-- 5. SHIFT SCHEDULE ROSTER (Managed by Dept Heads / Supervisors)
CREATE TABLE shift_roster (
    shift_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id),
    assigned_role platform_role NOT NULL,
    scheduled_start TIMESTAMPTZ NOT NULL,
    scheduled_end TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    
    CONSTRAINT chk_shift_times CHECK (scheduled_end > scheduled_start)
);

-- 6. SHIFT ACTIVATION LEDGER (Operational Gate: Supervisors must sign off before login)
CREATE TABLE shift_activations (
    activation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shift_id UUID NOT NULL REFERENCES shift_roster(shift_id) ON DELETE CASCADE,
    
    -- The Active Shift Supervisor on duty who pushed the button
    supervisor_approver_id UUID NOT NULL REFERENCES users(user_id), 
    
    activated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL, -- Calculated by Go to match the exact shift duration (e.g., 8 or 12 hours)
    is_active BOOLEAN NOT NULL DEFAULT true
);

-- 7. PERFORMANCE INDEXES FOR CYBER RECONNAISSANCE & AUTHENTICATION
-- Allows Go to verify a user's shift status instantly during login routing
CREATE INDEX idx_shift_lookup ON shift_roster (user_id, scheduled_start, scheduled_end);
-- Allows immediate matching of 802.1X cert names during structural admin actions
CREATE INDEX idx_hardware_gate ON administrative_hardware_gates (allowed_machine_cert_cn, allowed_network_subnet) WHERE is_active = true;
