"""Main application entry point for SQL Exporter."""

import os
import sys
import signal
import logging
import time
from pathlib import Path

import click
from dotenv import load_dotenv

from .config import ConfigLoader
from .database import QueryExecutor
from .metrics import MetricsCollector, MetricsServer

# Load environment variables
load_dotenv()

logger = logging.getLogger(__name__)


def setup_logging(log_level: str):
    """Setup logging configuration."""
    level = getattr(logging, log_level.upper(), logging.INFO)
    logging.basicConfig(
        level=level,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.StreamHandler(sys.stdout)
        ]
    )


class SQLExporter:
    """Main SQL Exporter application."""

    def __init__(self, config_path: str):
        self.config_path = config_path
        self.config = None
        self.query_executor = None
        self.metrics_collector = None
        self.metrics_server = None
        self._running = False

    def load_config(self):
        """Load configuration from file."""
        try:
            self.config = ConfigLoader.load_from_file(self.config_path)
            logger.info(f"Configuration loaded from: {self.config_path}")
        except Exception as e:
            logger.error(f"Failed to load configuration: {e}")
            raise

    def setup_databases(self):
        """Setup database connections."""
        self.query_executor = QueryExecutor()

        for db_config in self.config.databases.values():
            self.query_executor.add_database(db_config)
            logger.info(f"Added database: {db_config.name} ({db_config.driver})")

        # Test all connections
        test_results = self.query_executor.test_all_connections()
        for db_name, success in test_results.items():
            if success:
                logger.info(f"Database connection test passed: {db_name}")
            else:
                logger.error(f"Database connection test failed: {db_name}")

    def setup_metrics(self):
        """Setup metrics collection."""
        self.metrics_collector = MetricsCollector(self.query_executor)

        for query_config in self.config.queries:
            self.metrics_collector.add_query_config(query_config)
            logger.info(f"Added query: {query_config.name}")

    def start_server(self):
        """Start the HTTP metrics server."""
        self.metrics_server = MetricsServer(
            host=self.config.exporter.host,
            port=self.config.exporter.port
        )
        self.metrics_server.start()

    def run(self):
        """Run the SQL Exporter."""
        setup_logging(self.config.exporter.log_level)

        logger.info("Starting SQL Exporter")

        try:
            self.load_config()
            self.setup_databases()
            self.setup_metrics()
            self.start_server()

            # Start metrics collection
            self.metrics_collector.start_collection()
            self._running = True

            logger.info("SQL Exporter started successfully")

            # Keep the main thread alive
            while self._running:
                time.sleep(1)

        except KeyboardInterrupt:
            logger.info("Received interrupt signal")
        except Exception as e:
            logger.error(f"Error running SQL Exporter: {e}")
            raise
        finally:
            self.stop()

    def stop(self):
        """Stop the SQL Exporter."""
        logger.info("Stopping SQL Exporter")
        self._running = False

        if self.metrics_collector:
            self.metrics_collector.stop_collection()

        if self.metrics_server:
            self.metrics_server.stop()

        logger.info("SQL Exporter stopped")

    def collect_once(self, query_name: str = None):
        """Collect metrics once (for testing)."""
        setup_logging(self.config.exporter.log_level)

        logger.info("Running one-time metrics collection")

        try:
            self.load_config()
            self.setup_databases()
            self.setup_metrics()

            self.metrics_collector.collect_once(query_name)

            logger.info("One-time collection completed")

        except Exception as e:
            logger.error(f"Error during one-time collection: {e}")
            raise


@click.group()
@click.option('--config', '-c', default='config/config.yaml', help='Configuration file path')
@click.pass_context
def cli(ctx, config):
    """SQL to Prometheus metrics exporter."""
    ctx.ensure_object(dict)
    ctx.obj['config'] = config


@cli.command()
@click.pass_context
def run(ctx):
    """Run the SQL Exporter daemon."""
    config_path = ctx.obj['config']

    if not os.path.exists(config_path):
        click.echo(f"Error: Configuration file not found: {config_path}")
        sys.exit(1)

    exporter = SQLExporter(config_path)

    # Setup signal handlers
    def signal_handler(signum, frame):
        exporter.stop()
        sys.exit(0)

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    try:
        exporter.run()
    except Exception as e:
        click.echo(f"Error: {e}")
        sys.exit(1)


@cli.command()
@click.option('--query', '-q', help='Specific query to collect (optional)')
@click.pass_context
def collect(ctx, query):
    """Collect metrics once and exit."""
    config_path = ctx.obj['config']

    if not os.path.exists(config_path):
        click.echo(f"Error: Configuration file not found: {config_path}")
        sys.exit(1)

    exporter = SQLExporter(config_path)

    try:
        exporter.collect_once(query)
        click.echo("Collection completed successfully")
    except Exception as e:
        click.echo(f"Error: {e}")
        sys.exit(1)


@cli.command()
@click.pass_context
def test(ctx):
    """Test database connections."""
    config_path = ctx.obj['config']

    if not os.path.exists(config_path):
        click.echo(f"Error: Configuration file not found: {config_path}")
        sys.exit(1)

    try:
        config = ConfigLoader.load_from_file(config_path)
        query_executor = QueryExecutor()

        for db_config in config.databases.values():
            query_executor.add_database(db_config)

        test_results = query_executor.test_all_connections()

        click.echo("Database connection test results:")
        for db_name, success in test_results.items():
            status = "✓ PASS" if success else "✗ FAIL"
            click.echo(f"  {db_name}: {status}")

        if all(test_results.values()):
            click.echo("All database connections successful")
        else:
            click.echo("Some database connections failed")
            sys.exit(1)

    except Exception as e:
        click.echo(f"Error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    cli()