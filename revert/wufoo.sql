-- Revert wufoo

BEGIN;

DROP TABLE webhooks.wufoo;

COMMIT;
