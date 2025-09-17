"""Database connection and query execution."""

import sqlite3
import logging
from typing import List, Dict, Any, Optional
from contextlib import contextmanager

try:
    import pymysql
    pymysql.install_as_MySQLdb()
    MYSQL_AVAILABLE = True
except ImportError:
    MYSQL_AVAILABLE = False

try:
    import psycopg2
    import psycopg2.extras
    POSTGRESQL_AVAILABLE = True
except ImportError:
    POSTGRESQL_AVAILABLE = False

try:
    import pyodbc
    MSSQL_AVAILABLE = True
except ImportError:
    MSSQL_AVAILABLE = False

from .config import DatabaseConfig

logger = logging.getLogger(__name__)


class DatabaseError(Exception):
    """Database operation error."""
    pass


class DatabaseConnection:
    """Database connection manager."""

    def __init__(self, config: DatabaseConfig):
        self.config = config
        self._connection = None

    @contextmanager
    def get_connection(self):
        """Get database connection with context manager."""
        try:
            if self.config.driver == "sqlite":
                conn = sqlite3.connect(self.config.database)
                conn.row_factory = sqlite3.Row
            elif self.config.driver == "mysql":
                if not MYSQL_AVAILABLE:
                    raise DatabaseError("MySQL driver not available. Install pymysql.")
                conn = pymysql.connect(
                    host=self.config.host,
                    port=self.config.port or 3306,
                    database=self.config.database,
                    user=self.config.username,
                    password=self.config.password,
                    cursorclass=pymysql.cursors.DictCursor
                )
            elif self.config.driver == "postgresql":
                if not POSTGRESQL_AVAILABLE:
                    raise DatabaseError("PostgreSQL driver not available. Install psycopg2.")
                conn = psycopg2.connect(
                    host=self.config.host,
                    port=self.config.port or 5432,
                    database=self.config.database,
                    user=self.config.username,
                    password=self.config.password
                )
            elif self.config.driver == "mssql":
                if not MSSQL_AVAILABLE:
                    raise DatabaseError("MSSQL driver not available. Install pyodbc.")
                conn_str = (
                    f"DRIVER={{ODBC Driver 17 for SQL Server}};"
                    f"SERVER={self.config.host},{self.config.port or 1433};"
                    f"DATABASE={self.config.database};"
                    f"UID={self.config.username};"
                    f"PWD={self.config.password}"
                )
                conn = pyodbc.connect(conn_str)
            else:
                raise DatabaseError(f"Unsupported database driver: {self.config.driver}")

            yield conn
        except Exception as e:
            logger.error(f"Database connection error: {e}")
            raise DatabaseError(f"Failed to connect to database: {e}")
        finally:
            if 'conn' in locals():
                conn.close()

    def execute_query(self, sql: str, timeout: int = 30) -> List[Dict[str, Any]]:
        """Execute SQL query and return results."""
        logger.debug(f"Executing query: {sql}")

        with self.get_connection() as conn:
            try:
                if self.config.driver == "sqlite":
                    cursor = conn.cursor()
                    cursor.execute(sql)
                    rows = cursor.fetchall()
                    return [dict(row) for row in rows]

                elif self.config.driver == "mysql":
                    with conn.cursor() as cursor:
                        cursor.execute(sql)
                        return cursor.fetchall()

                elif self.config.driver == "postgresql":
                    with conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cursor:
                        cursor.execute(sql)
                        rows = cursor.fetchall()
                        return [dict(row) for row in rows]

                elif self.config.driver == "mssql":
                    cursor = conn.cursor()
                    cursor.execute(sql)
                    columns = [column[0] for column in cursor.description]
                    rows = cursor.fetchall()
                    return [dict(zip(columns, row)) for row in rows]

            except Exception as e:
                logger.error(f"Query execution error: {e}")
                raise DatabaseError(f"Failed to execute query: {e}")

    def test_connection(self) -> bool:
        """Test database connection."""
        try:
            with self.get_connection():
                logger.info(f"Successfully connected to database: {self.config.name}")
                return True
        except Exception as e:
            logger.error(f"Connection test failed for {self.config.name}: {e}")
            return False


class QueryExecutor:
    """SQL query executor with connection pooling."""

    def __init__(self):
        self.connections: Dict[str, DatabaseConnection] = {}

    def add_database(self, config: DatabaseConfig):
        """Add database configuration."""
        self.connections[config.name] = DatabaseConnection(config)

    def execute_query(self, database_name: str, sql: str, timeout: int = 30) -> List[Dict[str, Any]]:
        """Execute query on specified database."""
        if database_name not in self.connections:
            raise DatabaseError(f"Database '{database_name}' not configured")

        connection = self.connections[database_name]
        return connection.execute_query(sql, timeout)

    def test_all_connections(self) -> Dict[str, bool]:
        """Test all database connections."""
        results = {}
        for name, connection in self.connections.items():
            results[name] = connection.test_connection()
        return results