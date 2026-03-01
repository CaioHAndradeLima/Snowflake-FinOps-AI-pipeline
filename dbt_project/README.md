# dbt Project

This dbt project implements Step 3 (Modeling Layer) for FinOps.

Models:
- `stg_query_history`
- `stg_warehouse_metering`
- `fct_cost_per_query`
- `fct_wasteful_warehouses`

Run with local containerized dbt:

```bash
make local-up
make dbt-run
make dbt-test
```
