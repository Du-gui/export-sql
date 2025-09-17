-- PostgreSQL index usage query
-- Returns index usage statistics for performance monitoring

SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan as index_scans,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched,
    CASE
        WHEN idx_scan = 0 THEN 0
        ELSE ROUND((idx_tup_fetch::numeric / idx_scan), 2)
    END as avg_tuples_per_scan
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;