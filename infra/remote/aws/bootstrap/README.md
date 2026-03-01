# AWS Bootstrap (Terraform Execution Roles)

This layer creates two IAM roles used to run Terraform:

- `TerraformExecutionRoleDev`
- `TerraformExecutionRoleProd`

Both roles trust a configurable list of IAM principal ARNs and attach managed policies (default: `AdministratorAccess`).

## Usage

Use the helper script from project root:

```bash
bash infra/local/scripts/provision_aws_bootstrap.sh
bash infra/local/scripts/provision_aws_bootstrap.sh --apply
```

The script derives a trusted principal from your current AWS CLI identity and passes it to this Terraform layer.
