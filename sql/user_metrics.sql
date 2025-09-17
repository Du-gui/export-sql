-- User metrics query
-- Returns user statistics by region and type

SELECT
    region,
    user_type,
    COUNT(*) as user_count,
    AVG(login_frequency) as avg_login_freq,
    MAX(last_login) as last_activity,
    SUM(CASE WHEN active = 1 THEN 1 ELSE 0 END) as active_users
FROM users u
JOIN user_profiles up ON u.id = up.user_id
WHERE u.created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY region, user_type
ORDER BY region, user_type;