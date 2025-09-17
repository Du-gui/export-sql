"""Configuration management for SQL Exporter."""

import os
import yaml
from typing import Dict, List, Any, Optional
from dataclasses import dataclass


@dataclass
class DatabaseConfig:
    """Database connection configuration."""
    name: str
    driver: str  # mysql, postgresql, sqlite, mssql
    host: Optional[str] = None
    port: Optional[int] = None
    database: Optional[str] = None
    username: Optional[str] = None
    password: Optional[str] = None
    connection_string: Optional[str] = None

    def get_connection_string(self) -> str:
        """Generate connection string based on driver and parameters."""
        if self.connection_string:
            return self.connection_string

        if self.driver == "mysql":
            return f"mysql+pymysql://{self.username}:{self.password}@{self.host}:{self.port or 3306}/{self.database}"
        elif self.driver == "postgresql":
            return f"postgresql://{self.username}:{self.password}@{self.host}:{self.port or 5432}/{self.database}"
        elif self.driver == "sqlite":
            return f"sqlite:///{self.database}"
        elif self.driver == "mssql":
            return f"mssql+pyodbc://{self.username}:{self.password}@{self.host}:{self.port or 1433}/{self.database}?driver=ODBC+Driver+17+for+SQL+Server"
        else:
            raise ValueError(f"Unsupported database driver: {self.driver}")


@dataclass
class MetricConfig:
    """Metric configuration."""
    name: str
    help: str
    type: str  # gauge, counter, histogram
    labels: List[str] = None
    value_column: str = "value"

    def __post_init__(self):
        if self.labels is None:
            self.labels = []


@dataclass
class QueryConfig:
    """SQL query configuration."""
    name: str
    sql: str
    database: str
    metrics: List[MetricConfig]
    interval: int = 60  # seconds
    timeout: int = 30  # seconds


@dataclass
class ExporterConfig:
    """Main exporter configuration."""
    port: int = 9090
    host: str = "0.0.0.0"
    log_level: str = "INFO"


@dataclass
class Config:
    """Main configuration container."""
    databases: Dict[str, DatabaseConfig]
    queries: List[QueryConfig]
    exporter: ExporterConfig


class ConfigLoader:
    """Configuration file loader."""

    @staticmethod
    def load_from_file(config_path: str) -> Config:
        """Load configuration from YAML file."""
        if not os.path.exists(config_path):
            raise FileNotFoundError(f"Configuration file not found: {config_path}")

        with open(config_path, 'r', encoding='utf-8') as f:
            data = yaml.safe_load(f)

        return ConfigLoader._parse_config(data)

    @staticmethod
    def _parse_config(data: Dict[str, Any]) -> Config:
        """Parse configuration data into Config object."""
        # Parse databases with environment variable expansion
        databases = {}
        for name, db_data in data.get('databases', {}).items():
            # Expand environment variables in string values
            host = ConfigLoader._expand_env_vars(db_data.get('host'))
            username = ConfigLoader._expand_env_vars(db_data.get('username'))
            password = ConfigLoader._expand_env_vars(db_data.get('password'))
            database = ConfigLoader._expand_env_vars(db_data.get('database'))
            connection_string = ConfigLoader._expand_env_vars(db_data.get('connection_string'))

            databases[name] = DatabaseConfig(
                name=name,
                driver=db_data['driver'],
                host=host,
                port=db_data.get('port'),
                database=database,
                username=username,
                password=password,
                connection_string=connection_string
            )

        # Parse queries
        queries = []
        for query_data in data.get('queries', []):
            metrics = []
            for metric_data in query_data.get('metrics', []):
                metrics.append(MetricConfig(
                    name=metric_data['name'],
                    help=metric_data['help'],
                    type=metric_data['type'],
                    labels=metric_data.get('labels', []),
                    value_column=metric_data.get('value_column', 'value')
                ))

            queries.append(QueryConfig(
                name=query_data['name'],
                sql=query_data['sql'],
                database=query_data['database'],
                metrics=metrics,
                interval=query_data.get('interval', 60),
                timeout=query_data.get('timeout', 30)
            ))

        # Parse exporter config with environment variable support
        exporter_data = data.get('exporter', {})
        exporter = ExporterConfig(
            port=int(os.environ.get('EXPORTER_PORT', exporter_data.get('port', 9090))),
            host=os.environ.get('EXPORTER_HOST', exporter_data.get('host', '0.0.0.0')),
            log_level=os.environ.get('LOG_LEVEL', exporter_data.get('log_level', 'INFO'))
        )

        return Config(
            databases=databases,
            queries=queries,
            exporter=exporter
        )

    @staticmethod
    def _expand_env_vars(value: Optional[str]) -> Optional[str]:
        """Expand environment variables in string values."""
        if value is None:
            return None

        # Support ${VAR} and ${VAR:-default} syntax
        import re

        def replace_env_var(match):
            var_expr = match.group(1)
            if ':-' in var_expr:
                var_name, default_value = var_expr.split(':-', 1)
                return os.environ.get(var_name, default_value)
            else:
                return os.environ.get(var_expr, match.group(0))

        # Pattern to match ${VAR} or ${VAR:-default}
        pattern = r'\$\{([^}]+)\}'
        return re.sub(pattern, replace_env_var, value)