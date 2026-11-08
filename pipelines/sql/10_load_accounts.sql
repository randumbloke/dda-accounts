-- Load landed accounts into the staging dataset, as landed (P6-39). Accounts has no raw
-- dataset: its first stage is staging (datasets.yaml).
-- VERIFY IN BUILD (VA-64): run-time lineage from the Cloud Storage files appears for LOAD DATA.
LOAD DATA OVERWRITE `${core_project}.${business}_staging.accounts` (
  account_id STRING,
  customer_id STRING,
  product_type STRING,
  opened_date DATE,
  status STRING,
  currency STRING
)
FROM FILES (
  format = 'CSV',
  skip_leading_rows = 1,
  uris = ['gs://${landing_bucket}/accounts/*.csv']
);
