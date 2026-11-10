# dda-accounts

Domain repository of the **Accounts** business domain (`accounts-<env>`) of the Decentralised
Data Architecture (DDA) reference deployment: declarative files, the Terraform that turns them
into datasets, bindings, products and contracts for this domain only, and the domain's reference
pipeline (design §3, §6.1; change `mvp-phase-1-build`, phase 1). Applied by `tf-accounts-<tier>`
(with `single_deployer = true`, `tf-deployer`).

The `.tf` files, the pipeline code, tests, Dockerfile and CI are identical to `dda-customer`.
What differs: `datasets.yaml`, `products/`, `dq/`, `envs/*/*/<env>.tfvars`, `state.config`,
`pipelines/{config.yaml,steps.yaml,sql/,lineage/manifest.json}`.

## Layout

```text
datasets.yaml                    accounts_staging, accounts_curated, accounts_analytics (all non-sensitive)
products/account-summary.yaml    the Account Summary data product (§3.2)
dq/                              no scan specifications (dq/README.md explains why)
schemas/                         vendored JSON Schemas (schemas/VERSION)
envs/labels.json, envs/dev/core/, envs/dev/contract/   as in dda-customer (§6.13.2)
pipelines/                       P6-39 pipeline; consumes Customer Profile (config.yaml) for AT-23
.github/workflows/ci.yml         ci-checks
```

## Checks

```sh
terraform fmt -check -recursive
for s in envs/dev/core envs/dev/contract; do terraform -chdir=$s init -backend=false && terraform -chdir=$s validate && terraform -chdir=$s test -var-file=dev.tfvars; done
cd pipelines && uv sync && uv run pytest && uv run dda-pipeline validate --root ..
```

## Deployment

As `dda-customer` (README there, "Apply order on first deployment"): `core`, pipeline run, `core`
again, then `contract`. With `pipeline.enabled = true`, the `core` plan also reads Customer
Profile's published definition (`products/dev/customer-dev/customer-profile.json` in the hub state
bucket) to configure the `customer-accounts` step, so `dda-customer` `core` must have been applied
first. Landing files: `uv run dda-pipeline generate --business accounts --bucket kcdda-core-dwh-dev-accounts-landing`.

### AT-23 (cross-domain through the provisioning point)

1. The owner requests Customer Profile access for `accounts-ingest-dev` and approves it in the
   console; the account joins `dda-dp-customer-profile-dev-reader` (design §6.17; VA-30).
2. Run `accounts-ingest`. Step `customer-accounts` (`sql/22_customer_accounts.sql`) reads the
   published asset `kcdda-customer-analytics-dev.customer_analytics.customer_profile` and builds
   `accounts_curated.customer_accounts`. Before approval the step fails without failing the run
   (`optional: true`).
3. Run-time lineage links the product asset (`is_provisioning_point`) to the new table; the
   manifest declares it, so C14 records the upstream product (`upstream_data_products`).

## Acceptance tests served (design §6.18)

| AT | Artefact |
|---|---|
| AT-04 | Three datasets, labelled `cdmc-sensitivity=non-sensitive`, explicit access list, `ignore_changes` |
| AT-05 | Three dataset and one product binding; `bindings/dev/accounts-dev/bindings.json` |
| AT-06, AT-07 | As `dda-customer` |
| AT-08 | Account Summary with owners, approvers, `reader` access group, asset |
| AT-09 | `envs/dev/contract`: `refresh-cadence` daily 07:00, 120 minutes |
| AT-11, AT-12, AT-13 | Metadata changes from applies and pipeline runs |
| AT-15 | Account Summary has no scan, so it is the product "without results" (`NOT_EVALUATED`) |
| AT-16 | `contract.refresh_cadence`; skip a run of `accounts-build` |
| AT-19 | Fixture `at19`: a non-sensitive table with no lineage |
| AT-21 | `account_summary`: every run-time source declared → `VERIFIED` |
| AT-23 | `pipelines/config.yaml` `consumes`, step `customer-accounts`, manifest entry for `accounts_curated.customer_accounts` |
| AT-26 | Postconditions on every published file and on the consumed product definition |

AT-14, AT-17, AT-18 and AT-20 use `dda-customer` (sensitive tables, the deliberate undeclared source).

## VERIFY IN BUILD markers

Same as `dda-customer` (VA-12, VA-15, VA-34, VA-35, VA-42, VA-49, VA-55, VA-56, VA-58, VA-63,
VA-64, VA-80, VA-87, VA-94, estate), except that with no scan specifications the scan markers
(VA-34, VA-35, VA-63, VA-80) are not exercised by this domain. VA-30 (console approval adds the
account to the access group) is exercised by AT-23.

## Contract differences

As `dda-customer`'s README, plus: the generator, Terraform and pipeline code are shared with
`dda-customer` verbatim; the generator holds both domains' entity definitions so that account
customer IDs match generated customers.
