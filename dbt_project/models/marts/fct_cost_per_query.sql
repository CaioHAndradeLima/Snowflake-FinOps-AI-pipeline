with query_hourly as (
    select
        query_id,
        warehouse_name,
        user_name,
        role_name,
        query_type,
        execution_status,
        start_time,
        end_time,
        total_elapsed_time_ms,
        total_elapsed_time_seconds,
        bytes_scanned,
        rows_produced,
        usage_hour
    from {{ ref('stg_query_history') }}
),
warehouse_hourly as (
    select
        warehouse_name,
        usage_hour,
        sum(credits_used) as warehouse_credits_used
    from {{ ref('stg_warehouse_metering') }}
    group by 1, 2
),
query_totals as (
    select
        warehouse_name,
        usage_hour,
        sum(total_elapsed_time_seconds) as warehouse_query_seconds
    from query_hourly
    group by 1, 2
)
select
    q.query_id,
    q.warehouse_name,
    q.user_name,
    q.role_name,
    q.query_type,
    q.execution_status,
    q.start_time,
    q.end_time,
    q.total_elapsed_time_ms,
    q.total_elapsed_time_seconds,
    q.bytes_scanned,
    q.rows_produced,
    q.usage_hour,
    coalesce(w.warehouse_credits_used, 0) as warehouse_credits_used,
    coalesce(t.warehouse_query_seconds, 0) as warehouse_query_seconds,
    case
        when coalesce(t.warehouse_query_seconds, 0) > 0
            then q.total_elapsed_time_seconds / t.warehouse_query_seconds
        else 0
    end as query_time_weight_in_hour,
    case
        when coalesce(t.warehouse_query_seconds, 0) > 0
            then (q.total_elapsed_time_seconds / t.warehouse_query_seconds) * coalesce(w.warehouse_credits_used, 0)
        else 0
    end as estimated_credits_for_query
from query_hourly q
left join warehouse_hourly w
    on q.warehouse_name = w.warehouse_name
    and q.usage_hour = w.usage_hour
left join query_totals t
    on q.warehouse_name = t.warehouse_name
    and q.usage_hour = t.usage_hour
