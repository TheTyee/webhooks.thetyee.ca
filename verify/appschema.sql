-- Verify appschema

BEGIN;

-- XXX Add verifications here.
SELECT pg_catalog.has_schema_privilege('webhooks', 'usage');

ROLLBACK;
