-- Clean accounts into the curated dataset. Truncate and insert, never replace: replacing a
-- table would drop its catalog aspects (table contacts) and any table IAM.
CREATE TABLE IF NOT EXISTS `${core_project}.${business}_curated.accounts` (
  account_id STRING,
  customer_id STRING,
  product_type STRING,
  opened_date DATE,
  status STRING,
  currency STRING,
  load_ts TIMESTAMP
);

TRUNCATE TABLE `${core_project}.${business}_curated.accounts`;

INSERT INTO `${core_project}.${business}_curated.accounts`
SELECT
  account_id,
  customer_id,
  UPPER(product_type) AS product_type,
  opened_date,
  UPPER(status) AS status,
  UPPER(currency) AS currency,
  CURRENT_TIMESTAMP() AS load_ts
FROM `${core_project}.${business}_staging.accounts`
WHERE account_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY opened_date DESC) = 1;
