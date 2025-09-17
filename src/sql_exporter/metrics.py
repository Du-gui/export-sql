"""Prometheus metrics management and export."""

import time
import logging
import threading
from typing import Dict, List, Any, Optional
from prometheus_client import Gauge, Counter, Histogram, start_http_server, REGISTRY
from prometheus_client.core import CollectorRegistry

from .config import QueryConfig, MetricConfig
from .database import QueryExecutor, DatabaseError

logger = logging.getLogger(__name__)


class MetricsCollector:
    """Collects and manages Prometheus metrics from SQL queries."""

    def __init__(self, query_executor: QueryExecutor):
        self.query_executor = query_executor
        self.metrics: Dict[str, Any] = {}
        self.query_configs: List[QueryConfig] = []
        self._stop_event = threading.Event()
        self._threads: List[threading.Thread] = []

    def add_query_config(self, query_config: QueryConfig):
        """Add a query configuration for metrics collection."""
        self.query_configs.append(query_config)

        # Create Prometheus metrics for this query
        for metric_config in query_config.metrics:
            if metric_config.name not in self.metrics:
                self.metrics[metric_config.name] = self._create_metric(metric_config)

    def _create_metric(self, metric_config: MetricConfig):
        """Create a Prometheus metric based on configuration."""
        metric_name = metric_config.name
        metric_help = metric_config.help
        metric_labels = metric_config.labels or []

        if metric_config.type == "gauge":
            return Gauge(metric_name, metric_help, metric_labels)
        elif metric_config.type == "counter":
            return Counter(metric_name, metric_help, metric_labels)
        elif metric_config.type == "histogram":
            return Histogram(metric_name, metric_help, metric_labels)
        else:
            raise ValueError(f"Unsupported metric type: {metric_config.type}")

    def _collect_metrics_for_query(self, query_config: QueryConfig):
        """Collect metrics for a single query configuration."""
        try:
            logger.debug(f"Collecting metrics for query: {query_config.name}")

            # Execute the SQL query
            results = self.query_executor.execute_query(
                query_config.database,
                query_config.sql,
                query_config.timeout
            )

            if not results:
                logger.warning(f"No results returned for query: {query_config.name}")
                return

            # Process results for each metric
            for metric_config in query_config.metrics:
                metric = self.metrics[metric_config.name]
                self._update_metric(metric, metric_config, results)

        except DatabaseError as e:
            logger.error(f"Database error for query {query_config.name}: {e}")
        except Exception as e:
            logger.error(f"Unexpected error for query {query_config.name}: {e}")

    def _update_metric(self, metric, metric_config: MetricConfig, results: List[Dict[str, Any]]):
        """Update a Prometheus metric with query results."""
        value_column = metric_config.value_column

        for row in results:
            if value_column not in row:
                logger.warning(f"Value column '{value_column}' not found in query results")
                continue

            try:
                value = float(row[value_column])
            except (ValueError, TypeError) as e:
                logger.warning(f"Cannot convert value to float: {row[value_column]}, error: {e}")
                continue

            # Extract label values
            label_values = {}
            for label in metric_config.labels:
                if label in row:
                    label_values[label] = str(row[label])
                else:
                    logger.warning(f"Label '{label}' not found in query results")
                    label_values[label] = ""

            # Update metric based on type
            if metric_config.type == "gauge":
                if label_values:
                    metric.labels(**label_values).set(value)
                else:
                    metric.set(value)
            elif metric_config.type == "counter":
                if label_values:
                    metric.labels(**label_values).inc(value)
                else:
                    metric.inc(value)
            elif metric_config.type == "histogram":
                if label_values:
                    metric.labels(**label_values).observe(value)
                else:
                    metric.observe(value)

    def _query_worker(self, query_config: QueryConfig):
        """Worker thread for periodic query execution."""
        while not self._stop_event.is_set():
            start_time = time.time()

            try:
                self._collect_metrics_for_query(query_config)
            except Exception as e:
                logger.error(f"Error in query worker for {query_config.name}: {e}")

            # Calculate sleep time to maintain interval
            execution_time = time.time() - start_time
            sleep_time = max(0, query_config.interval - execution_time)

            if self._stop_event.wait(sleep_time):
                break

    def start_collection(self):
        """Start periodic metrics collection."""
        logger.info("Starting metrics collection")

        for query_config in self.query_configs:
            thread = threading.Thread(
                target=self._query_worker,
                args=(query_config,),
                name=f"query-{query_config.name}",
                daemon=True
            )
            thread.start()
            self._threads.append(thread)
            logger.info(f"Started collection thread for query: {query_config.name}")

    def stop_collection(self):
        """Stop metrics collection."""
        logger.info("Stopping metrics collection")
        self._stop_event.set()

        for thread in self._threads:
            thread.join(timeout=5)

        self._threads.clear()

    def collect_once(self, query_name: Optional[str] = None):
        """Collect metrics once (for testing or manual execution)."""
        if query_name:
            # Collect for specific query
            for query_config in self.query_configs:
                if query_config.name == query_name:
                    self._collect_metrics_for_query(query_config)
                    return
            logger.warning(f"Query '{query_name}' not found")
        else:
            # Collect for all queries
            for query_config in self.query_configs:
                self._collect_metrics_for_query(query_config)


class MetricsServer:
    """HTTP server for Prometheus metrics."""

    def __init__(self, host: str = "0.0.0.0", port: int = 9090):
        self.host = host
        self.port = port
        self._server = None

    def start(self):
        """Start the metrics HTTP server."""
        try:
            start_http_server(self.port, addr=self.host)
            logger.info(f"Metrics server started on {self.host}:{self.port}")
            logger.info(f"Metrics available at http://{self.host}:{self.port}/metrics")
        except Exception as e:
            logger.error(f"Failed to start metrics server: {e}")
            raise

    def stop(self):
        """Stop the metrics HTTP server."""
        # prometheus_client doesn't provide a direct way to stop the server
        # The server will stop when the process ends
        pass