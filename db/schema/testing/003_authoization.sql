-- ============================================================
-- 003_authorization.sql
--
-- Public Safety Platform
--
-- Purpose:
-- Implements multi-party authorization decisions.
--
-- Security Principle:
--
-- No single administrator, department, or credential
-- can grant operational access.
--
-- Authorization requires independent attestations.
--
-- This schema does NOT:
--
-- - create identities
-- - authenticate users
-- - define operational roles
-- - issue sessions
--
-- It evaluates whether existing trust facts
-- are sufficient to authorize an action.
--
-- Dependencies:
--
-- 000_trust_foundation.sql
-- 001_device_trust.sql
-- 002_operational_authority.sql
--
-- ============================================================


CREATE EXTENSION IF NOT EXISTS "uuid-ossp";



------------------------------------------------------------
-- AUTHORIZATION REQUEST STATES
------------------------------------------------------------

CREATE TYPE authorization_request_state AS ENUM (

    'REQUESTED',

    'PENDING_APPROVAL',

    'APPROVED',

    'DENIED',

    'EXPIRED',

    'REVOKED'

);



------------------------------------------------------------
-- AUTHORIZATION REQUESTS
--
-- Example:
--
-- "Grant John Dispatcher II CAD access"
--
-- This is a request.
--
-- Not access.
--
------------------------------------------------------------

CREATE TABLE authorization_requests (

    authorization_request_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    subject_person_id UUID NOT NULL
        REFERENCES persons(person_id),

    requested_capability_id UUID NOT NULL
        REFERENCES operational_capabilities(capability_id),

    requested_role_id UUID
        REFERENCES operational_roles(role_id),

    requested_by UUID NOT NULL
        REFERENCES persons(person_id),

    reason TEXT NOT NULL,

    state authorization_request_state
        NOT NULL DEFAULT 'REQUESTED',

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now(),

    expires_at TIMESTAMPTZ

);



------------------------------------------------------------
-- APPROVAL TYPES
--
-- Defines what kind of approval is required.
--
-- Examples:
--
-- HR confirms employee
-- IT confirms account/device
-- Operations confirms role
--
------------------------------------------------------------

CREATE TYPE approval_authority_type AS ENUM (

    'IDENTITY_APPROVAL',

    'DEVICE_APPROVAL',

    'OPERATIONAL_APPROVAL',

    'SECURITY_APPROVAL',

    'EXECUTIVE_APPROVAL'

);



------------------------------------------------------------
-- REQUIRED APPROVAL POLICY
--
-- Defines what approvals are needed.
--
-- Example:
--
-- Dispatcher Access:
--
-- HR
-- IT
-- Operations
--
------------------------------------------------------------

CREATE TABLE authorization_policies (

    policy_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    policy_name VARCHAR(150)
        NOT NULL UNIQUE,

    description TEXT NOT NULL,

    minimum_approvals INTEGER
        NOT NULL DEFAULT 1,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- POLICY APPROVAL REQUIREMENTS
------------------------------------------------------------

CREATE TABLE authorization_policy_requirements (

    requirement_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    policy_id UUID NOT NULL
        REFERENCES authorization_policies(policy_id),

    authority_type approval_authority_type
        NOT NULL,

    required BOOLEAN
        NOT NULL DEFAULT true

);



------------------------------------------------------------
-- REQUEST APPROVAL LEDGER
--
-- IMPORTANT:
--
-- This table should be append-only.
--
-- Never update approval records.
--
-- Add new approval events.
--
------------------------------------------------------------

CREATE TABLE authorization_approval_events (

    approval_event_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    authorization_request_id UUID NOT NULL
        REFERENCES authorization_requests(
            authorization_request_id
        ),

    authority_type approval_authority_type
        NOT NULL,

    approving_person_id UUID NOT NULL
        REFERENCES persons(person_id),

    approval_action VARCHAR(50)
        NOT NULL,

    approval_reason TEXT NOT NULL,


    certificate_thumbprint VARCHAR(255),


    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- DIGITAL SIGNATURES
--
-- Allows cryptographic proof of approval.
--
------------------------------------------------------------

CREATE TABLE authorization_signatures (

    signature_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    approval_event_id UUID NOT NULL
        REFERENCES authorization_approval_events(
            approval_event_id
        ),

    signer_person_id UUID NOT NULL
        REFERENCES persons(person_id),

    signing_certificate VARCHAR(255)
        NOT NULL,

    signature_algorithm VARCHAR(100)
        NOT NULL,

    signature_value BYTEA
        NOT NULL,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- AUTHORIZATION DECISIONS
--
-- The result of policy evaluation.
--
-- This is NOT permanent access.
--
-- This permits session creation.
--
------------------------------------------------------------

CREATE TABLE authorization_decisions (

    decision_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    authorization_request_id UUID NOT NULL
        REFERENCES authorization_requests(
            authorization_request_id
        ),

    decision VARCHAR(50)
        NOT NULL,

    evaluated_by VARCHAR(100)
        NOT NULL,

    evaluation_reason TEXT NOT NULL,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- AUTHORIZATION REVOCATIONS
--
-- Revocation is an event.
--
-- Not deletion.
--
------------------------------------------------------------

CREATE TABLE authorization_revocations (

    revocation_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    authorization_request_id UUID NOT NULL
        REFERENCES authorization_requests(
            authorization_request_id
        ),

    revoked_by UUID NOT NULL
        REFERENCES persons(person_id),

    reason TEXT NOT NULL,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- ACCESS BOUNDARIES
--
-- Limits where/how authorization applies.
--
-- Examples:
--
-- CAD only
-- Admin console only
-- Police dispatch only
--
------------------------------------------------------------

CREATE TABLE authorization_scope (

    scope_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    authorization_request_id UUID NOT NULL
        REFERENCES authorization_requests(
            authorization_request_id
        ),

    resource_type VARCHAR(100)
        NOT NULL,

    resource_identifier VARCHAR(255)
        NOT NULL

);



------------------------------------------------------------
-- INDEXES
------------------------------------------------------------


CREATE INDEX idx_auth_request_person
ON authorization_requests(subject_person_id);


CREATE INDEX idx_auth_request_state
ON authorization_requests(state);


CREATE INDEX idx_approval_request
ON authorization_approval_events(
    authorization_request_id
);


CREATE INDEX idx_authorization_decision
ON authorization_decisions(
    authorization_request_id
);


CREATE INDEX idx_revocation_lookup
ON authorization_revocations(
    authorization_request_id
);