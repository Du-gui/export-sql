-- Order analytics query
-- Returns order statistics for monitoring business metrics

SELECT
    DATE(created_at) as order_date,
    status,
    payment_method,
    COUNT(*) as order_count,
    SUM(total_amount) as total_revenue,
    AVG(total_amount) as avg_order_value,
    COUNT(DISTINCT customer_id) as unique_customers
FROM orders
WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY DATE(created_at), status, payment_method
ORDER BY order_date DESC, status, payment_method;