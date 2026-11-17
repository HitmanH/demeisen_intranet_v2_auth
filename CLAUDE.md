# demeisen_intranet_v2_auth: notes for Claude sessions

Shared sign-in for Demeisen apps. Read README.md first.

## Rules
- The Cognito user pool is data. Never delete or replace it, never remove `DeletionPolicy: Retain`,
  `DeletionProtection: ACTIVE` or the stack policy. `python3 tools/check-guardrails.py pool/demeisen-pool.yaml` must pass.
- Never change `DomainPrefix` or `PoolName` in pool/demeisen-pool.yaml: that replaces the resource.
- Pool changes go through the "Deploy pool" workflow (GitHub environment `data`, needs Russell's approval). Never
  deploy the pool stack from a laptop.
- Nothing Demeisen-specific (users, passwords, account numbers) belongs in python/ or js/: they are meant to be shared.
- AWS: account 642552605309, eu-west-2. Deploys use GitHub OIDC roles; no AWS keys in the repo or in CI secrets.
