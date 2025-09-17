-- MySQL initialization script for testing
-- Creates sample tables and data for SQL Exporter testing

CREATE DATABASE IF NOT EXISTS testdb;
USE testdb;

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    region VARCHAR(50),
    user_type ENUM('premium', 'standard', 'trial') DEFAULT 'standard',
    active BOOLEAN DEFAULT TRUE,
    login_frequency INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL,
    INDEX idx_region (region),
    INDEX idx_user_type (user_type),
    INDEX idx_active (active)
);

-- Orders table
CREATE TABLE IF NOT EXISTS orders (
    id INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT,
    product_id INT,
    status ENUM('pending', 'processing', 'shipped', 'delivered', 'cancelled') DEFAULT 'pending',
    payment_method ENUM('credit_card', 'paypal', 'bank_transfer', 'cash') DEFAULT 'credit_card',
    total_amount DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_status (status),
    INDEX idx_payment_method (payment_method),
    INDEX idx_created_at (created_at)
);

-- API logs table
CREATE TABLE IF NOT EXISTS api_logs (
    id INT PRIMARY KEY AUTO_INCREMENT,
    endpoint VARCHAR(255),
    method VARCHAR(10),
    status_code INT,
    response_time_ms INT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_endpoint (endpoint),
    INDEX idx_timestamp (timestamp)
);

-- Insert sample users data
INSERT INTO users (username, email, region, user_type, active, login_frequency, last_login) VALUES
('john_doe', 'john@example.com', 'US-East', 'premium', TRUE, 15, NOW() - INTERVAL 1 HOUR),
('jane_smith', 'jane@example.com', 'US-West', 'standard', TRUE, 8, NOW() - INTERVAL 2 HOUR),
('bob_wilson', 'bob@example.com', 'EU-Central', 'trial', TRUE, 3, NOW() - INTERVAL 1 DAY),
('alice_brown', 'alice@example.com', 'US-East', 'premium', TRUE, 22, NOW() - INTERVAL 30 MINUTE),
('charlie_davis', 'charlie@example.com', 'APAC', 'standard', FALSE, 0, NULL),
('diana_white', 'diana@example.com', 'EU-West', 'premium', TRUE, 18, NOW() - INTERVAL 3 HOUR),
('eve_black', 'eve@example.com', 'US-West', 'trial', TRUE, 5, NOW() - INTERVAL 6 HOUR),
('frank_green', 'frank@example.com', 'APAC', 'standard', TRUE, 12, NOW() - INTERVAL 4 HOUR);

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
(2, 110, 'pending', 'credit_card', 249.99);

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
('/api/auth/logout', 'POST', 200, 23);

-- Create a user for the SQL Exporter
CREATE USER IF NOT EXISTS 'exporter'@'%' IDENTIFIED BY 'exporter_password';
GRANT SELECT ON testdb.* TO 'exporter'@'%';
GRANT SELECT ON information_schema.* TO 'exporter'@'%';
GRANT PROCESS ON *.* TO 'exporter'@'%';
FLUSH PRIVILEGES;