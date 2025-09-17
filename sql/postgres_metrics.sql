-- PostgreSQL database metrics query
-- Returns comprehensive database performance and activity metrics

SELECT
    'database_size' as metric_name,
    datname as database_name,
    pg_size_pretty(pg_database_size(datname)) as size_pretty,
    pg_database_size(datname) as size_bytes,
    'gauge' as metric_type
FROM pg_database
WHERE datname NOT IN ('template0', 'template1', 'postgres')

UNION ALL

SELECT
    'active_connections' as metric_name,
    datname as database_name,
    '' as size_pretty,
    COUNT(*) as size_bytes,
    'gauge' as metric_type
FROM pg_stat_activity
WHERE state = 'active'
GROUP BY datname

UNION ALL

SELECT
    'idle_connections' as metric_name,
    datname as database_name,
    '' as size_pretty,
    COUNT(*) as size_bytes,
    'gauge' as metric_type
FROM pg_stat_activity
WHERE state = 'idle'
GROUP BY datname

UNION ALL

SELECT
    'total_connections' as metric_name,
    datname as database_name,
    '' as size_pretty,
    COUNT(*) as size_bytes,
    'gauge' as metric_type
FROM pg_stat_activity
GROUP BY datname;