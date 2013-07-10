-- Deploy wufoo
-- requires: appschema

BEGIN;

SET client_min_messages = 'warning';
 
CREATE TABLE webhooks.wufoo (
    entry_id        TEXT    PRIMARY KEY,
    email           TEXT    NOT NULL,
    subscription    TEXT    NOT NULL,
    timestamp TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    form_url        TEXT    NOT NULL,
    date_created TIMESTAMP  NOT NULL,
    form_data       TEXT    NOT NULL,
    wc_status       BOOLEAN DEFAULT FALSE NOT NULL,
    wc_response     TEXT    NULL
);

COMMIT;
