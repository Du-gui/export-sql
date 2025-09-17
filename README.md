# SQL Exporter

一个将SQL查询结果导出为Prometheus指标的Python工具。支持多种数据库类型，可以将查询结果转换为不同类型的Prometheus指标，支持标签和多维度指标。

## 功能特性

- 🗄️ **多数据库支持**: MySQL、PostgreSQL、SQLite、SQL Server
- 📊 **多种指标类型**: Gauge、Counter、Histogram
- 🏷️ **标签支持**: 将查询结果作为Prometheus指标标签
- ⚡ **高性能**: 支持并发查询和异步指标更新
- 🔧 **灵活配置**: YAML配置文件，支持环境变量
- 📈 **实时监控**: HTTP服务器提供 `/metrics` 端点
- 🐳 **容器化**: 支持 Docker 和 Kubernetes 部署
- 🔒 **安全**: 非 root 用户运行，只读文件系统
- 📋 **监控集成**: 自动 Prometheus 发现和 Grafana 可视化

## 安装

1. 克隆项目并安装依赖：

```bash
cd export-sql
pip install -r requirements.txt
```

2. 根据需要安装对应的数据库驱动：

```bash
# MySQL
pip install pymysql

# PostgreSQL
pip install psycopg2-binary

# SQL Server
pip install pyodbc
```

## 快速开始

1. **配置数据库和查询**

编辑 `config/config.yaml` 文件，配置你的数据库连接和查询：

```yaml
databases:
  my_db:
    driver: mysql
    host: localhost
    port: 3306
    database: myapp
    username: user
    password: password

queries:
  - name: user_count
    database: my_db
    interval: 60
    sql: "SELECT COUNT(*) as value FROM users WHERE active = 1"
    metrics:
      - name: active_users_total
        help: "Total number of active users"
        type: gauge
        value_column: value
```

2. **运行应用**

```bash
# 运行导出器
python main.py run

# 使用自定义配置文件
python main.py -c /path/to/config.yaml run

# 测试数据库连接
python main.py test

# 单次执行指标收集
python main.py collect
```

3. **访问指标**

访问 `http://localhost:9090/metrics` 查看Prometheus指标。

### Docker 运行

```bash
# 构建镜像
docker build -t sql-exporter .

# 运行容器
docker run -d \
  --name sql-exporter \
  -p 9090:9090 \
  -v $(pwd)/config:/app/config:ro \
  -e EXPORTER_PORT=9090 \
  -e POSTGRES_HOST=your-db-host \
  -e POSTGRES_USER=your-user \
  -e POSTGRES_PASS=your-password \
  sql-exporter

# 使用 Docker Compose
docker-compose up -d
```

### Kubernetes 部署

```bash
# 快速部署
kubectl apply -k k8s/

# 或使用构建脚本
./examples/build-and-deploy.sh all

# 检查状态
kubectl get pods -n monitoring -l app=sql-exporter
```

详细的 Kubernetes 部署指南请参考 [examples/k8s-deploy.md](examples/k8s-deploy.md)。

## 配置文件详解

### 数据库配置

```yaml
databases:
  mysql_example:
    driver: mysql
    host: localhost
    port: 3306
    database: myapp
    username: ${MYSQL_USER}  # 支持环境变量
    password: ${MYSQL_PASS}

  postgres_example:
    driver: postgresql
    host: localhost
    port: 5432
    database: analytics
    username: postgres
    password: password

  sqlite_example:
    driver: sqlite
    database: ./data/app.db
```

### 查询和指标配置

```yaml
queries:
  - name: user_stats_by_region
    database: mysql_example
    interval: 120  # 查询间隔（秒）
    timeout: 30    # 查询超时（秒）
    sql: |
      SELECT
        region,
        user_type,
        COUNT(*) as user_count,
        AVG(login_frequency) as avg_login_freq
      FROM users
      GROUP BY region, user_type
    metrics:
      - name: users_by_region
        help: "Number of users by region and type"
        type: gauge
        labels: [region, user_type]  # 使用查询结果作为标签
        value_column: user_count     # 指定值列
      - name: avg_login_frequency
        help: "Average login frequency"
        type: gauge
        labels: [region, user_type]
        value_column: avg_login_freq
```

### 指标类型

- **gauge**: 瞬时值指标，可增可减（如当前用户数、CPU使用率）
- **counter**: 累计值指标，只能增加（如总请求数、总销售额）
- **histogram**: 分布统计指标（如响应时间分布）

## 使用示例

### 1. 简单的计数指标

```yaml
- name: total_orders
  database: app_db
  interval: 60
  sql: "SELECT COUNT(*) as value FROM orders"
  metrics:
    - name: orders_total
      help: "Total number of orders"
      type: counter
      value_column: value
```

### 2. 带标签的多维指标

```yaml
- name: sales_by_category
  database: app_db
  interval: 300
  sql: |
    SELECT
      category,
      region,
      SUM(amount) as total_sales,
      COUNT(*) as order_count
    FROM orders o
    JOIN products p ON o.product_id = p.id
    WHERE o.created_at >= DATE_SUB(NOW(), INTERVAL 1 DAY)
    GROUP BY category, region
  metrics:
    - name: daily_sales_amount
      help: "Daily sales amount by category and region"
      type: gauge
      labels: [category, region]
      value_column: total_sales
    - name: daily_order_count
      help: "Daily order count by category and region"
      type: gauge
      labels: [category, region]
      value_column: order_count
```

### 3. 系统监控指标

```yaml
- name: database_performance
  database: app_db
  interval: 30
  sql: |
    SELECT
      'connections' as metric_type,
      COUNT(*) as value
    FROM information_schema.processlist
    UNION ALL
    SELECT
      'slow_queries',
      variable_value
    FROM information_schema.global_status
    WHERE variable_name = 'Slow_queries'
  metrics:
    - name: mysql_performance_metrics
      help: "MySQL performance metrics"
      type: gauge
      labels: [metric_type]
      value_column: value
```

## 命令行选项

```bash
# 基本命令
python main.py --help

# 运行导出器
python main.py run

# 测试数据库连接
python main.py test

# 单次收集指标
python main.py collect

# 收集特定查询的指标
python main.py collect --query user_count

# 使用自定义配置文件
python main.py -c custom_config.yaml run
```

## 环境变量

在配置文件中可以使用环境变量：

```yaml
databases:
  prod_db:
    driver: mysql
    host: ${DB_HOST:-localhost}
    port: ${DB_PORT:-3306}
    username: ${DB_USER}
    password: ${DB_PASS}
```

对应的环境变量文件 `.env`：

```
DB_HOST=prod-mysql.example.com
DB_PORT=3306
DB_USER=metrics_user
DB_PASS=secure_password
```

## 最佳实践

1. **查询优化**: 确保SQL查询有适当的索引，避免全表扫描
2. **间隔设置**: 根据数据更新频率设置合理的查询间隔
3. **标签设计**: 避免高基数标签（如用户ID），使用分类标签
4. **监控资源**: 监控导出器本身的CPU和内存使用情况
5. **错误处理**: 查看日志文件排查连接或查询问题

## 故障排除

### 常见问题

1. **数据库连接失败**
   - 检查数据库服务是否运行
   - 验证连接参数（主机、端口、用户名、密码）
   - 确认防火墙设置

2. **指标未更新**
   - 检查SQL查询是否返回结果
   - 验证value_column配置是否正确
   - 查看应用日志了解详细错误

3. **内存使用过高**
   - 减少查询频率
   - 优化SQL查询，减少结果集大小
   - 检查是否有内存泄漏



## 许可证

MIT License