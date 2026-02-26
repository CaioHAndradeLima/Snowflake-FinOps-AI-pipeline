# Snowflake Terraform Example (Reference Only)

This directory is an example implementation to use as a stable reference for this project.

Goals:
- Keep a known-good Terraform/Snowflake provider model pinned by version.
- Show the project naming convention for `prod` and `dev`.
- Reduce future breakages caused by provider/version mismatches.

Important:
- Treat this as a reference baseline, not as a fully production-ready deployment.
- Use environment-specific credentials and state separation outside this folder.
- Never commit real secrets in `*.tfvars`.

## Naming Pattern

- Prod uses base names:
  - `SENTINEL`
  - `WH_SENTINEL`
  - `ACCOUNTADMIN`
- Dev uses `_DEV` suffix:
  - `SENTINEL_DEV`
  - `WH_SENTINEL_DEV`
  - Role defaults to `ACCOUNTADMIN` (can be customized with `dev_role_name`)

## Files

- `versions.tf`: pinned Terraform and provider versions.
- `provider.tf`: Snowflake provider config.
- `variables.tf`: input variables.
- `locals.tf`: env-based name resolution.
- `main.tf`: database + schemas.
- `warehouse.tf`: warehouse resource.
- `grants.tf`: baseline grants for the selected role.
- `terraform.example.tfvars`: non-secret example values.
