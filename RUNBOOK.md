# Runbook: dda-accounts, phase 1 (`dev`)

How to deploy this repository the first time, then run each acceptance test (design §6.18) that it
serves. In phase 1 every apply runs as `tf-deployer` from the merge build (§6.7.2). The commands
show the same steps by hand.

```sh
export REGION=australia-southeast1 CORE=kcdda-core-dwh-dev ANA=kcdda-accounts-analytics-dev \
       CANA=kcdda-customer-analytics-dev STATE=tfstate-pltfrm-ngnrng HUBSTATE=kcdda-dgov-hub-nonprod-dda-state \
       LANDING=kcdda-core-dwh-dev-accounts-landing DOMAIN=accounts-dev
```

## 0. Preconditions

As `dda-customer` RUNBOOK §0, for `accounts-dev` and the groups `dda-accounts-dev-owners`,
`dda-accounts-dev-stewards` and `dda-dp-account-summary-dev-owners`. For AT-23, `dda-customer` must
be deployed through its step 6, so that `gs://$HUBSTATE/products/dev/customer-dev/customer-profile.json`
exists and `customer_profile` has rows.

## 1. First deployment

| Step | Command | Evidence |
|---|---|---|
| 1. `core` apply 1 | `cd envs/dev/core && terraform init -backend-config=state.config && terraform apply -var-file=dev.tfvars -var commit_sha=$(git rev-parse HEAD)` | Three datasets, Account Summary, `dda-dp-account-summary-dev-reader`, three dataset and one product binding |
| 2. Land files | `cd pipelines && uv sync && uv run dda-pipeline generate --business accounts --bucket $LANDING` | `gs://$LANDING/{accounts,transactions}/*.csv` |
| 3. Pipeline run | `gcloud run jobs execute accounts-ingest --project $CORE --region $REGION --wait`, then `gcloud run jobs execute accounts-build --project $ANA --region $REGION --wait`. Without jobs: the `DDA_*` variables and `uv run dda-pipeline run --stage ingest` as `accounts-ingest-dev`, then `--stage build` as `accounts-analytics-dev` | Staging, curated and analytics tables. Before AT-23 approval the optional step `customer-accounts` logs `optional step customer-accounts failed: ... Access Denied` and the run still succeeds |
| 4. `core` apply 2 | Same as step 1 | The asset `account-summary` and the table contacts on `accounts_curated.accounts`. No scans: `dq/README.md` |
| 5. `contract` apply | `cd envs/dev/contract && terraform init -backend-config=state.config && terraform apply -var-file=dev.tfvars` | `refresh-cadence` Daily, 07:00, 120 |
| 6. Image and jobs | Merge a change under `pipelines/`: the `dda-accounts-image` trigger (bootstrap, P6-43) runs the merge gate, builds and pushes `dda-pipelines/accounts-pipeline:<sha>` and writes its digest to `gs://tfstate-pltfrm-ngnrng/outputs/dda-accounts/images.json`. Then set `pipeline.image` to `<repository>@<digest>` from that file and `pipeline.enabled = true`. With the jobs on, the `core` plan reads Customer Profile's published definition | Jobs `accounts-ingest`, `accounts-build`. Env `DDA_CONSUMED_TABLES={"customer_profile":"kcdda-customer-analytics-dev.customer_analytics.customer_profile"}` |

## 2. Acceptance tests

| AT | Steps | Evidence to record |
|---|---|---|
| AT-04 | `for d in accounts_staging accounts_curated; do bq show --format=prettyjson $CORE:$d \| jq '.labels, .access'; done; bq show --format=prettyjson $ANA:accounts_analytics \| jq '.labels, .access'` | `cdmc-sensitivity=non-sensitive`, `dda-stage`, `dda-domain=accounts-dev`. Creation entries only, plus later entries; no `projectReaders` |
| AT-05 | Bindings list per subdomain (see `dda-customer` RUNBOOK AT-05); `gcloud storage cat gs://$HUBSTATE/bindings/dev/$DOMAIN/bindings.json` | `ds-accounts-staging`, `ds-accounts-curated`, `ds-accounts-analytics`, `dp-account-summary` |
| AT-06 | `terraform plan -var-file=dev.tfvars -detailed-exitcode` in both stacks | Exit code 0 |
| AT-08 | `curl -s -H "Authorization: Bearer $(gcloud auth print-access-token)" https://dataplex.googleapis.com/v1/projects/$ANA/locations/$REGION/dataProducts/account-summary` | Owners, approvers, `reader`, asset `account-summary` |
| AT-09 | Look up the `dataplex_entry` from `gs://$STATE/outputs/dda-accounts/dev/outputs.json` | `refresh-cadence` set; contract aspect only from `evaluator-dev` |
| AT-15 | After step 5 | Account Summary `aggregate_dq_status = NOT_EVALUATED` (no scan results) and a product status finding |
| AT-16 | `gcloud scheduler jobs pause accounts-build-daily --project $ANA --location $REGION` past 09:00 | `freshness_status = LATE`; finding |
| AT-19 | Day 1: `gcloud run jobs execute accounts-ingest --args=fixtures,--at,at19 --project $CORE --region $REGION --wait`; assert on day 3 or later | `INSUFFICIENT_EVIDENCE` on `accounts_curated.at19_no_lineage` (non-sensitive) |
| AT-21 | After step 3 | `VERIFIED` on `accounts_analytics.account_summary` (every run-time source declared) |
| AT-23 | 1. As the owner, in the console, request access to Customer Profile for `accounts-ingest-dev@kcdda-core-dwh-dev.iam.gserviceaccount.com` (access group `reader`) and approve it. 2. `gcloud identity groups memberships list --group-email=dda-dp-customer-profile-dev-reader@mikegyoung.joonix.net`. 3. `gcloud run jobs execute accounts-ingest --project $CORE --region $REGION --wait`. 4. `bq head -n 5 $CORE:accounts_curated.customer_accounts` | The account is in the group (VA-30). The run logs step `customer-accounts` done, and the table has `customer_segment` filled. C14 on `accounts_curated.customer_accounts` records `upstream_data_products` = Customer Profile (needs `cdmc-provisioning-point` on the asset; RUNBOOK note below) |
| AT-26 | Plan before `cdmc-governance` has published `accounts-dev`, or against an empty scratch state bucket | Plan fails at the published-file postcondition; nothing applied. Offline: `terraform test` (`missing_published_file_fails_plan`, `no_discovery_config_fails_plan`) |

Note for AT-23: the kc-control-plane C14 walk records a product only when the upstream asset
carries `cdmc-provisioning-point` with `is_provisioning_point = true`. That aspect's writer (C3) is
a later phase, and the walk continues past the asset to the Customer domain's own sources. Both
points are in the integration report.
