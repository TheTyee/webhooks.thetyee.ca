-- Revert appschema

BEGIN;

-- XXX Add DDLs here.
DROP SCHEMA webhooks;

COMMIT;
