select
    query_id,
    user_name,
    role_name,
    warehouse_name,
    database_name,
    schema_name,
    query_type,
    start_time,
    end_time,
    execution_status,
    error_code,
    error_message,
    coalesce(bytes_scanned, 0) as bytes_scanned,
    coalesce(rows_produced, 0) as rows_produced,
    coalesce(credits_used_cloud_services, 0) as credits_used_cloud_services,
    coalesce(total_elapsed_time, 0) as total_elapsed_time_ms,
    coalesce(total_elapsed_time, 0) / 1000.0 as total_elapsed_time_seconds,
    date_trunc('hour', start_time) as usage_hour
from {{ source('bronze', 'QUERY_HISTORY_RAW') }}
where query_id is not null
