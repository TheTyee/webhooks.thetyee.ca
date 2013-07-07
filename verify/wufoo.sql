-- Verify wufoo

BEGIN;

SELECT  entry_id, email, subscription, timestamp, form_url, date_created, form_data
  FROM webhooks.wufoo
 WHERE FALSE;

ROLLBACK;
