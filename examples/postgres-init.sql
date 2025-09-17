-- PostgreSQL initialization script for testing
-- Creates sample tables and data for SQL Exporter testing

-- Create database (if running as superuser)
-- CREATE DATABASE testdb;
-- \c testdb;

-- Create schema
CREATE SCHEMA IF NOT EXISTS public;

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    region VARCHAR(50),
    user_type VARCHAR(20) CHECK (user_type IN ('premium', 'standard', 'trial')) DEFAULT 'standard',
    active BOOLEAN DEFAULT TRUE,
    login_frequency INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_users_region ON users(region);
CREATE INDEX IF NOT EXISTS idx_users_type ON users(user_type);
CREATE INDEX IF NOT EXISTS idx_users_active ON users(active);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);

-- Orders table
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER,
    product_id INTEGER,
    status VARCHAR(20) CHECK (status IN ('pending', 'processing', 'shipped', 'delivered', 'cancelled')) DEFAULT 'pending',
    payment_method VARCHAR(20) CHECK (payment_method IN ('credit_card', 'paypal', 'bank_transfer', 'cash')) DEFAULT 'credit_card',
    total_amount DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for orders
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_payment_method ON orders(payment_method);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at);

-- API logs table
CREATE TABLE IF NOT EXISTS api_logs (
    id SERIAL PRIMARY KEY,
    endpoint VARCHAR(255),
    method VARCHAR(10),
    status_code INTEGER,
    response_time_ms INTEGER,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for api_logs
CREATE INDEX IF NOT EXISTS idx_api_logs_endpoint ON api_logs(endpoint);
CREATE INDEX IF NOT EXISTS idx_api_logs_timestamp ON api_logs(timestamp);

-- User analytics table (for PostgreSQL specific examples)
CREATE TABLE IF NOT EXISTS user_analytics (
    id SERIAL PRIMARY KEY,
    user_id INTEGER,
    region VARCHAR(50),
    user_type VARCHAR(20),
    login_frequency INTEGER,
    session_duration INTEGER, -- in minutes
    page_views INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index for user_analytics
CREATE INDEX IF NOT EXISTS idx_user_analytics_region_type ON user_analytics(region, user_type);
CREATE INDEX IF NOT EXISTS idx_user_analytics_created_at ON user_analytics(created_at);

-- Insert sample users data
INSERT INTO users (username, email, region, user_type, active, login_frequency, last_login) VALUES
('john_doe', 'john@example.com', 'US-East', 'premium', TRUE, 15, NOW() - INTERVAL '1 hour'),
('jane_smith', 'jane@example.com', 'US-West', 'standard', TRUE, 8, NOW() - INTERVAL '2 hours'),
('bob_wilson', 'bob@example.com', 'EU-Central', 'trial', TRUE, 3, NOW() - INTERVAL '1 day'),
('alice_brown', 'alice@example.com', 'US-East', 'premium', TRUE, 22, NOW() - INTERVAL '30 minutes'),
('charlie_davis', 'charlie@example.com', 'APAC', 'standard', FALSE, 0, NULL),
('diana_white', 'diana@example.com', 'EU-West', 'premium', TRUE, 18, NOW() - INTERVAL '3 hours'),
('eve_black', 'eve@example.com', 'US-West', 'trial', TRUE, 5, NOW() - INTERVAL '6 hours'),
('frank_green', 'frank@example.com', 'APAC', 'standard', TRUE, 12, NOW() - INTERVAL '4 hours'),
('grace_blue', 'grace@example.com', 'EU-Central', 'premium', TRUE, 25, NOW() - INTERVAL '45 minutes'),
('henry_red', 'henry@example.com', 'US-East', 'standard', TRUE, 9, NOW() - INTERVAL '2 hours')
ON CONFLICT DO NOTHING;

-- Insert sample orders data
INSERT INTO orders (customer_id, product_id, status, payment_method, total_amount) VALUES
(1, 101, 'delivered', 'credit_card', 299.99),
(2, 102, 'shipped', 'paypal', 149.99),
(3, 103, 'processing', 'bank_transfer', 89.99),
(4, 104, 'pending', 'credit_card', 199.99),
(1, 105, 'delivered', 'credit_card', 79.99),
(5, 106, 'cancelled', 'paypal', 349.99),
(6, 107, 'shipped', 'credit_card', 129.99),
(7, 108, 'processing', 'bank_transfer', 59.99),
(8, 109, 'delivered', 'paypal', 419.99),
(2, 110, 'pending', 'credit_card', 249.99),
(9, 111, 'shipped', 'credit_card', 179.99),
(10, 112, 'delivered', 'paypal', 329.99)
ON CONFLICT DO NOTHING;

-- Insert sample API logs data
INSERT INTO api_logs (endpoint, method, status_code, response_time_ms) VALUES
('/api/users', 'GET', 200, 45),
('/api/orders', 'POST', 201, 123),
('/api/products', 'GET', 200, 67),
('/api/users/1', 'GET', 200, 34),
('/api/orders/1', 'PUT', 200, 89),
('/api/auth/login', 'POST', 200, 156),
('/api/users', 'GET', 200, 52),
('/api/orders', 'GET', 200, 78),
('/api/products/search', 'GET', 200, 234),
('/api/auth/logout', 'POST', 200, 23),
('/api/dashboard', 'GET', 200, 145),
('/api/reports', 'GET', 200, 289),
('/api/settings', 'PUT', 200, 67),
('/api/notifications', 'GET', 200, 43),
('/api/profile', 'PUT', 200, 92)
ON CONFLICT DO NOTHING;

-- Insert sample user analytics data
INSERT INTO user_analytics (user_id, region, user_type, login_frequency, session_duration, page_views) VALUES
(1, 'US-East', 'premium', 15, 45, 120),
(2, 'US-West', 'standard', 8, 30, 85),
(3, 'EU-Central', 'trial', 3, 15, 25),
(4, 'US-East', 'premium', 22, 60, 180),
(5, 'APAC', 'standard', 0, 0, 0),
(6, 'EU-West', 'premium', 18, 50, 145),
(7, 'US-West', 'trial', 5, 20, 35),
(8, 'APAC', 'standard', 12, 35, 95),
(9, 'EU-Central', 'premium', 25, 65, 200),
(10, 'US-East', 'standard', 9, 25, 70)
ON CONFLICT DO NOTHING;

-- Create a user for the SQL Exporter (if running as superuser)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'exporter') THEN
        CREATE ROLE exporter WITH LOGIN PASSWORD 'exporter_password';
    END IF;
END
$$;

-- Grant permissions
GRANT CONNECT ON DATABASE postgres TO exporter;
GRANT USAGE ON SCHEMA public TO exporter;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO exporter;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO exporter;

-- Grant access to PostgreSQL system views
GRANT SELECT ON pg_stat_database TO exporter;
GRANT SELECT ON pg_stat_user_tables TO exporter;
GRANT SELECT ON pg_stat_user_indexes TO exporter;
GRANT SELECT ON pg_stat_activity TO exporter;
GRANT SELECT ON pg_database TO exporter;

-- For pg_stat_statements (if available)
GRANT SELECT ON pg_stat_statements TO exporter;