-- Clean transactions into the curated dataset; drop rows with no account.
CREATE TABLE IF NOT EXISTS `${core_project}.${business}_curated.transactions` (
  txn_id STRING,
  account_id STRING,
  txn_ts TIMESTAMP,
  amount NUMERIC,
  txn_type STRING,
  load_ts TIMESTAMP
);

TRUNCATE TABLE `${core_project}.${business}_curated.transactions`;

INSERT INTO `${core_project}.${business}_curated.transactions`
SELECT
  txn_id,
  account_id,
  txn_ts,
  amount,
  UPPER(txn_type) AS txn_type,
  CURRENT_TIMESTAMP() AS load_ts
FROM `${core_project}.${business}_staging.transactions`
WHERE account_id IS NOT NULL;
