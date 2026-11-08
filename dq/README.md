# Data quality scan specifications

None. Every Accounts dataset is `non-sensitive`, and in phase 1 the classifier is off, so no
Accounts table is sensitive (design §3.6: a dataset labelled `cdmc-sensitivity=sensitive`, or a
column classified `CONFIDENTIAL` or `RESTRICTED`). A specification is therefore not required for
any table. Account Summary deliberately has no scan, so it is the AT-15 product "without results"
(`aggregate_dq_status = NOT_EVALUATED`).

Add `dq/<dataset>/<table>.yaml` (schema `schemas/dq_spec.schema.json`) when a table becomes
sensitive, for example once the classifier rates a column of `accounts_curated.customer_accounts`.
