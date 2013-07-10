-- Verify wufoo

BEGIN;

SELECT  entry_id, email, subscription, timestamp, form_url, date_created, form_data, wc_status, wc_response
  FROM webhooks.wufoo
 WHERE FALSE;

ROLLBACK;
