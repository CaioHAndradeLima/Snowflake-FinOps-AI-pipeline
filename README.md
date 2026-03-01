# ❄️ Snowflake Sentinel: Autonomous FinOps Lakehouse

## Project Overview

The Snowflake Sentinel is a production-grade FinOps Agent designed to solve the "Cloud Bill Shock" problem common in
high-growth US startups. By utilizing a Lakehouse Architecture, it monitors Snowflake's own metadata to identify runaway
costs, inefficient SQL patterns, and idle resources—providing AI-generated optimization suggestions natively within the
platform.

## The Problem

Many organizations struggle with unpredictable Snowflake costs due to:

- Sub-optimal SQL queries causing massive "disk spilling."
- Warehouses with excessive idle time before auto-suspension.
- Lack of visibility into which specific users/teams are burning credits.

Solution: This project automates the audit process, using Generative AI to act as a virtual DBA, reducing monthly spend
by an estimated 15–20%.

## 🏗️ Architecture & Layers

| Layer          | Technology              | Responsibility                                              |
|----------------|-------------------------|-------------------------------------------------------------|
| Data Source    | Snowflake Account Usage | Extracting QUERY_HISTORY and METERING_HISTORY.              |
| Data Lake      | AWS S3 + Apache Iceberg | Open-table format storage to reduce vendor lock-in.         |
| Ingestion      | Snowpark (Python)       | Extracting metadata and loading into the Iceberg Lakehouse. |
| Transformation | dbt (Data Build Tool)   | Modeling raw logs into "Cost per Query" metrics.            |
| Intelligence   | Snowflake Cortex        | LLM-based analysis of SQL text for optimization.            |
| Consumption    | Streamlit in Snowflake  | An interactive "Wall of Shame" & FinOps dashboard.          |

## 📁 Package Structure

```plaintext
snowflake-sentinel/
├── infra/                  # Infrastructure as Code
│   ├── main.tf             # AWS S3 & IAM configuration
│   ├── snowflake_setup.tf  # Storage integrations & RBAC
│   └── variables.tf
├── dbt_project/            # dbt Transformation Layer
│   ├── models/
│   │   ├── staging/        # Cleaned metadata
│   │   └── marts/          # Cost & Efficiency metrics
│   └── dbt_project.yml
├── scripts/                # Snowpark & Ingestion
│   ├── extraction_logic.py # Python logic for S3/Iceberg sync
│   └── cortex_analysis.py  # LLM prompting for SQL optimization
├── streamlit/              # Native Snowflake App
│   └── dashboard_app.py    # FinOps UI
├── .github/workflows/      # CI/CD (GitHub Actions)
└── README.md
```

## 🛠️ Setup & Requirements

## 🔧 Current Infra Structure (Local vs Remote)

This project separates infrastructure into two clear scopes:

- `infra/local`: local developer runtime with Docker containers.
- `infra/remote`: remote Snowflake infrastructure provisioned with Terraform.
- Detailed infra guide: `infra/README.md`.

### Local Infra (`infra/local`)

Local containers are used to standardize tooling on macOS/Linux without changing your host environment:

- `app`: Python runtime for Snowpark/scripts.
- `dbt`: dbt-snowflake runtime for transformations.
- `terraform`: Terraform CLI runtime targeting `infra/remote/snowflake`.

Configuration comes from one file:

- `infra/local/.env`

Environment pattern:

- Prod uses base names (`SNOWFLAKE_DATABASE`, `SNOWFLAKE_WAREHOUSE`, `SNOWFLAKE_ROLE`).
- Dev uses `_DEV` names (`SNOWFLAKE_DATABASE_DEV`, `SNOWFLAKE_WAREHOUSE_DEV`, `SNOWFLAKE_ROLE_DEV`).
- `APP_ENV=dev|prod` selects which values are used by tooling.

### Remote Infra (`infra/remote`)

`infra/remote/snowflake` is Terraform-based and provisions Snowflake resources (database, schemas, warehouse, grants).

### AWS Bootstrap Execution Model (First Time)

To create Terraform execution roles, the first run must use an AWS identity that already has permission to create IAM
roles/policies in the target AWS account (for example, an admin SSO profile).

Bootstrap creates:

- `TerraformExecutionRoleDev`
- `TerraformExecutionRoleProd`

After bootstrap:

- day-to-day Terraform should run by assuming these roles (instead of broad admin credentials).

First-time commands:

```bash
cd /Users/caiohandradelima/PycharmProjects/snowflake-costs-performance-ai-pipeline
aws sts get-caller-identity
make aws-bootstrap-plan
make aws-bootstrap-apply
```

One-command first-time dev flow:

```bash
make aws-first-time-dev
```

What the bootstrap script does:

- reads your current AWS CLI identity.
- uses that identity as trusted principal for role assumption.
- runs Terraform in `infra/remote/aws/bootstrap`.

## ▶️ Run Local Containers

From project root:

```bash
make local-up
```

Check status:

```bash
make local-ps
```

Open shells:

```bash
make local-shell-app
make local-shell-dbt
make local-shell-tf
```

Stop everything:

```bash
make local-down
```

### 1. Infrastructure (Terraform)

This project uses Terraform to ensure the environment is reproducible (Local → Remote).

Local Setup: Install Terraform and AWS CLI. Configure your aws_access_key.

Execution:

```bash
cd infra
terraform init
terraform apply
```

This will create the S3 Bucket for the Iceberg Lakehouse and the IAM Roles required for Snowflake to talk to AWS.

### 2. Snowflake Configuration

You will need a Snowflake account (Enterprise Edition or higher for Cortex/Iceberg features).

- Create a Storage Integration to link Snowflake to the S3 bucket created by Terraform.
- Enable Snowflake Cortex access for your functional role.

### 3. Local Development

- Python 3.10+: Required for Snowpark.
- dbt-snowflake: For the modeling layer.

```bash
pip install snowflake-snowpark-python dbt-snowflake streamlit
```

## 🚀 The "Wow" Factor: AI Optimization

The heart of this project is the Cortex Intelligence Layer. Instead of just showing a graph of "expensive queries," the
Sentinel uses the llama3-70b model within Snowflake to analyze the query profile:

```python
# Example logic used in the project
def get_ai_advice(query_text):
    prompt = f"Analyze this Snowflake SQL for FinOps optimization: {query_text}"
    return session.sql(f"SELECT SNOWFLAKE.CORTEX.COMPLETE('llama3-70b', '{prompt}')").collect()
```

## 📈 Expected Impact

- Observability: 100% visibility into credit consumption.
- Efficiency: Automated identification of the top 5% most wasteful queries.
- Cost: Significant reduction in storage costs by utilizing Apache Iceberg for long-term log retention outside of
  standard Snowflake tables.
