BEGIN;

CREATE SCHEMA IF NOT EXISTS security;


DROP TABLE IF EXISTS security.session_context CASCADE;


CREATE TABLE security.session_context
(
    session_id UUID PRIMARY KEY
        REFERENCES sessions(session_id),

    identity_id UUID NOT NULL
        REFERENCES identities(identity_id),

    person_id UUID NOT NULL
        REFERENCES persons(person_id),

    agency_id UUID NOT NULL
        REFERENCES agencies(agency_id),

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()
);



CREATE INDEX idx_session_context_person
ON security.session_context(person_id);



CREATE INDEX idx_session_context_agency
ON security.session_context(agency_id);



CREATE OR REPLACE FUNCTION security.current_identity()

RETURNS UUID

LANGUAGE sql

STABLE

AS
$$

SELECT identity_id

FROM security.session_context

WHERE session_id =
(
    current_setting(
        'app.session_id',
        true
    )::uuid
);

$$;



CREATE OR REPLACE FUNCTION security.current_person()

RETURNS UUID

LANGUAGE sql

STABLE

AS
$$

SELECT person_id

FROM security.session_context

WHERE session_id =
(
    current_setting(
        'app.session_id',
        true
    )::uuid
);

$$;



CREATE OR REPLACE FUNCTION security.current_agency()

RETURNS UUID

LANGUAGE sql

STABLE

AS
$$

SELECT agency_id

FROM security.session_context

WHERE session_id =
(
    current_setting(
        'app.session_id',
        true
    )::uuid
);

$$;



COMMIT;
