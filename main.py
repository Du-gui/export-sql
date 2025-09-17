#!/usr/bin/env python3
"""Entry point for SQL Exporter."""

import sys
import os

# Add the src directory to the Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

from sql_exporter.main import cli

if __name__ == '__main__':
    cli()