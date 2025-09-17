# Kubernetes Deployment Guide

本指南介绍如何在 Kubernetes 集群中部署 SQL Exporter。

## 前置要求

- Kubernetes 集群 (v1.19+)
- kubectl 配置正确
- Docker 或 Podman 用于构建镜像
- (可选) Kustomize 用于自定义部署
- (可选) Prometheus Operator 用于自动发现

## 快速部署

### 1. 构建 Docker 镜像

```bash
# 构建镜像
docker build -t sql-exporter:latest .

# 如果使用私有镜像仓库
docker tag sql-exporter:latest your-registry.com/sql-exporter:latest
docker push your-registry.com/sql-exporter:latest
```

### 2. 配置密钥

```bash
# 创建命名空间
kubectl create namespace monitoring

# 创建数据库连接密钥
kubectl create secret generic sql-exporter-secrets \
  --from-literal=postgres-user=postgres \
  --from-literal=postgres-password=your-postgres-password \
  --from-literal=mysql-user=root \
  --from-literal=mysql-password=your-mysql-password \
  --namespace=monitoring
```

### 3. 部署应用

```bash
# 使用 Kustomize 部署
kubectl apply -k k8s/

# 或者逐个部署
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/serviceaccount.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

### 4. 验证部署

```bash
# 检查 Pod 状态
kubectl get pods -n monitoring -l app=sql-exporter

# 检查服务状态
kubectl get svc -n monitoring -l app=sql-exporter

# 查看日志
kubectl logs -n monitoring -l app=sql-exporter -f

# 端口转发测试
kubectl port-forward -n monitoring svc/sql-exporter-service 9090:9090
curl http://localhost:9090/metrics
```

## 自定义配置

### 修改配置文件

编辑 `k8s/configmap.yaml` 中的配置：

```yaml
data:
  config.yaml: |
    databases:
      your_db:
        driver: postgresql
        host: ${POSTGRES_HOST}
        port: ${POSTGRES_PORT}
        database: ${POSTGRES_DATABASE}
        username: ${POSTGRES_USER}
        password: ${POSTGRES_PASS}

    queries:
      - name: your_metric
        database: your_db
        interval: 60
        sql: "SELECT COUNT(*) as value FROM your_table"
        metrics:
          - name: your_metric_total
            help: "Description of your metric"
            type: gauge
            value_column: value
```

### 环境变量配置

在 `k8s/deployment.yaml` 中添加环境变量：

```yaml
env:
- name: YOUR_DB_HOST
  value: "your-db-service"
- name: YOUR_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: your-secrets
      key: db-password
```

### 资源限制

调整 `k8s/deployment.yaml` 中的资源配置：

```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "200m"
  limits:
    memory: "512Mi"
    cpu: "1000m"
```

## Prometheus 集成

### 使用 Prometheus Operator

如果您的集群安装了 Prometheus Operator，SQL Exporter 会自动被发现：

```bash
# 部署 ServiceMonitor
kubectl apply -f k8s/servicemonitor.yaml

# 检查 ServiceMonitor
kubectl get servicemonitor -n monitoring
```

### 手动配置 Prometheus

在 Prometheus 配置中添加以下 scrape 配置：

```yaml
scrape_configs:
  - job_name: 'sql-exporter'
    kubernetes_sd_configs:
      - role: endpoints
        namespaces:
          names:
            - monitoring
    relabel_configs:
      - source_labels: [__meta_kubernetes_service_name]
        action: keep
        regex: sql-exporter-service
      - source_labels: [__meta_kubernetes_endpoint_port_name]
        action: keep
        regex: metrics
```

## 高可用部署

### 多副本部署

```yaml
# 在 deployment.yaml 中设置多个副本
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
```

### 亲和性配置

```yaml
# 添加 Pod 反亲和性
spec:
  template:
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - sql-exporter
              topologyKey: kubernetes.io/hostname
```

## 监控和告警

### 健康检查

应用已配置了健康检查：

```yaml
livenessProbe:
  httpGet:
    path: /metrics
    port: metrics
  initialDelaySeconds: 30
  periodSeconds: 30

readinessProbe:
  httpGet:
    path: /metrics
    port: metrics
  initialDelaySeconds: 5
  periodSeconds: 10
```

### 常用指标监控

设置以下 Prometheus 告警规则：

```yaml
groups:
- name: sql-exporter
  rules:
  - alert: SQLExporterDown
    expr: up{job="sql-exporter"} == 0
    for: 5m
    annotations:
      summary: "SQL Exporter is down"

  - alert: SQLExporterHighErrorRate
    expr: rate(sql_exporter_errors_total[5m]) > 0.1
    for: 5m
    annotations:
      summary: "High error rate in SQL Exporter"
```

## 故障排除

### 常见问题

1. **Pod 无法启动**
   ```bash
   kubectl describe pod -n monitoring -l app=sql-exporter
   kubectl logs -n monitoring -l app=sql-exporter
   ```

2. **数据库连接失败**
   ```bash
   # 检查密钥
   kubectl get secrets -n monitoring
   kubectl describe secret sql-exporter-secrets -n monitoring

   # 测试数据库连接
   kubectl exec -it -n monitoring deployment/sql-exporter -- python main.py test
   ```

3. **指标不可用**
   ```bash
   # 检查服务端点
   kubectl get endpoints -n monitoring sql-exporter-service

   # 端口转发测试
   kubectl port-forward -n monitoring svc/sql-exporter-service 9090:9090
   curl http://localhost:9090/metrics
   ```

### 调试模式

临时启用调试模式：

```bash
kubectl patch deployment sql-exporter -n monitoring -p '{"spec":{"template":{"spec":{"containers":[{"name":"sql-exporter","env":[{"name":"LOG_LEVEL","value":"DEBUG"}]}]}}}}'
```

## 升级部署

### 滚动更新

```bash
# 更新镜像
kubectl set image deployment/sql-exporter sql-exporter=sql-exporter:v2.0.0 -n monitoring

# 检查更新状态
kubectl rollout status deployment/sql-exporter -n monitoring

# 如需回滚
kubectl rollout undo deployment/sql-exporter -n monitoring
```

### 配置更新

```bash
# 更新 ConfigMap
kubectl apply -f k8s/configmap.yaml

# 重启 Deployment 以应用新配置
kubectl rollout restart deployment/sql-exporter -n monitoring
```

## 清理

```bash
# 删除所有资源
kubectl delete -k k8s/

# 或删除命名空间（如果专用）
kubectl delete namespace monitoring
```