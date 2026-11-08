-- Build the Account Summary product table in the analytics dataset (design §3.4, pipeline-built
-- table). Runs as the analytics account, which reads curated and writes analytics. The 30-day
-- window ends at the latest transaction, so the deterministic synthetic data stays in range.
CREATE TABLE IF NOT EXISTS `${analytics_project}.${business}_analytics.account_summary` (
  account_id STRING,
  customer_id STRING,
  product_type STRING,
  status STRING,
  opened_date DATE,
  txn_count_30d INT64,
  credit_total_30d NUMERIC,
  debit_total_30d NUMERIC,
  last_txn_ts TIMESTAMP,
  refreshed_at TIMESTAMP
);

TRUNCATE TABLE `${analytics_project}.${business}_analytics.account_summary`;

INSERT INTO `${analytics_project}.${business}_analytics.account_summary`
WITH window_end AS (
  SELECT MAX(txn_ts) AS end_ts FROM `${core_project}.${business}_curated.transactions`
),
activity AS (
  SELECT
    t.account_id,
    COUNT(*) AS txn_count_30d,
    SUM(IF(t.txn_type = 'CREDIT', t.amount, 0)) AS credit_total_30d,
    SUM(IF(t.txn_type = 'DEBIT', t.amount, 0)) AS debit_total_30d,
    MAX(t.txn_ts) AS last_txn_ts
  FROM `${core_project}.${business}_curated.transactions` AS t, window_end AS w
  WHERE t.txn_ts > TIMESTAMP_SUB(w.end_ts, INTERVAL 30 DAY)
  GROUP BY t.account_id
)
SELECT
  a.account_id,
  a.customer_id,
  a.product_type,
  a.status,
  a.opened_date,
  COALESCE(x.txn_count_30d, 0) AS txn_count_30d,
  COALESCE(x.credit_total_30d, 0) AS credit_total_30d,
  COALESCE(x.debit_total_30d, 0) AS debit_total_30d,
  x.last_txn_ts,
  CURRENT_TIMESTAMP() AS refreshed_at
FROM `${core_project}.${business}_curated.accounts` AS a
LEFT JOIN activity AS x
  USING (account_id);
