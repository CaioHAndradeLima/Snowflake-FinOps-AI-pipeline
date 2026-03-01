with query_by_hour as (
    select
        warehouse_name,
        usage_hour,
        sum(total_elapsed_time_seconds) as query_execution_seconds
    from {{ ref('stg_query_history') }}
    group by 1, 2
),
metering_by_hour as (
    select
        warehouse_name,
        usage_hour,
        sum(credits_used) as credits_used
    from {{ ref('stg_warehouse_metering') }}
    group by 1, 2
),
joined as (
    select
        m.warehouse_name,
        m.usage_hour,
        m.credits_used,
        coalesce(q.query_execution_seconds, 0) as query_execution_seconds,
        greatest(3600 - coalesce(q.query_execution_seconds, 0), 0) as estimated_idle_seconds
    from metering_by_hour m
    left join query_by_hour q
        on m.warehouse_name = q.warehouse_name
        and m.usage_hour = q.usage_hour
)
select
    warehouse_name,
    usage_hour,
    credits_used,
    query_execution_seconds,
    estimated_idle_seconds,
    estimated_idle_seconds / 3600.0 as idle_ratio,
    case
        when estimated_idle_seconds / 3600.0 >= 0.5 then true
        else false
    end as is_wasteful_hour
from joined
