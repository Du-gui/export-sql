-- System health monitoring query
-- Returns key database performance metrics

SELECT
    'active_connections' as metric_name,
    COUNT(*) as value,
    'gauge' as metric_type
FROM information_schema.processlist
WHERE command != 'Sleep'

UNION ALL

SELECT
    'total_connections' as metric_name,
    variable_value as value,
    'gauge' as metric_type
FROM information_schema.global_status
WHERE variable_name = 'Threads_connected'

UNION ALL

SELECT
    'queries_per_second' as metric_name,
    variable_value as value,
    'counter' as metric_type
FROM information_schema.global_status
WHERE variable_name = 'Queries'

UNION ALL

SELECT
    'slow_queries' as metric_name,
    variable_value as value,
    'counter' as metric_type
FROM information_schema.global_status
WHERE variable_name = 'Slow_queries'

UNION ALL

SELECT
    'innodb_buffer_pool_usage' as metric_name,
    ROUND((pages_data * 16384) / (pages_total * 16384) * 100, 2) as value,
    'gauge' as metric_type
FROM (
    SELECT
        (SELECT variable_value FROM information_schema.global_status WHERE variable_name = 'Innodb_buffer_pool_pages_data') as pages_data,
        (SELECT variable_value FROM information_schema.global_status WHERE variable_name = 'Innodb_buffer_pool_pages_total') as pages_total
) buffer_stats;