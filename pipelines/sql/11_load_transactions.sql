-- Load landed transactions into the staging dataset (P6-39).
LOAD DATA OVERWRITE `${core_project}.${business}_staging.transactions` (
  txn_id STRING,
  account_id STRING,
  txn_ts TIMESTAMP,
  amount NUMERIC,
  txn_type STRING
)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://${landing_bucket}/transactions/*.csv']
);
