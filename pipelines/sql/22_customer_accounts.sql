-- AT-23: build a curated table from another domain's data product, read through its published
-- asset (the provisioning point), ${consumed_customer_profile}. Runs as accounts-ingest-<env>,
-- which reads the asset as a member of Customer Profile's reader access group (console approval,
-- design §6.17). Only non-personal columns are copied, so the non-sensitive dataset holds no
-- CONFIDENTIAL or RESTRICTED column (design §3.3, C6 placement).
CREATE TABLE IF NOT EXISTS `${core_project}.${business}_curated.customer_accounts` (
  account_id STRING,
  customer_id STRING,
  product_type STRING,
  status STRING,
  customer_segment STRING,
  customer_state STRING,
  load_ts TIMESTAMP
);

TRUNCATE TABLE `${core_project}.${business}_curated.customer_accounts`;

INSERT INTO `${core_project}.${business}_curated.customer_accounts`
SELECT
  a.account_id,
  a.customer_id,
  a.product_type,
  a.status,
  p.segment_name AS customer_segment,
  p.state AS customer_state,
  CURRENT_TIMESTAMP() AS load_ts
FROM `${core_project}.${business}_curated.accounts` AS a
LEFT JOIN `${consumed_customer_profile}` AS p
  USING (customer_id);
