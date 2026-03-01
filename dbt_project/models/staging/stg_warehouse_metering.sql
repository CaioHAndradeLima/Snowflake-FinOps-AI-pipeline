select
    start_time,
    end_time,
    warehouse_id,
    warehouse_name,
    coalesce(credits_used, 0) as credits_used,
    coalesce(credits_used_compute, 0) as credits_used_compute,
    coalesce(credits_used_cloud_services, 0) as credits_used_cloud_services,
    date_trunc('hour', start_time) as usage_hour
from {{ source('bronze', 'WAREHOUSE_METERING_RAW') }}
where warehouse_name is not null
