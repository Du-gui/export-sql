# Multi-stage build for smaller final image
FROM python:3.11-slim as builder

# Set working directory
WORKDIR /app

# Install system dependencies for building
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    unixodbc-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Production stage
FROM python:3.11-slim

# Create non-root user
RUN groupadd -r sqlexporter && useradd -r -g sqlexporter sqlexporter

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    unixodbc \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy Python packages from builder stage
COPY --from=builder /root/.local /home/sqlexporter/.local

# Copy application code
COPY src/ ./src/
COPY main.py .

# Create directories for config and data
RUN mkdir -p /app/config /app/sql /app/data && \
    chown -R sqlexporter:sqlexporter /app

# Copy default configuration
COPY config/ ./config/
COPY sql/ ./sql/

# Make sure the user has access to .local/bin
ENV PATH=/home/sqlexporter/.local/bin:$PATH

# Switch to non-root user
USER sqlexporter

# Environment variables with defaults
ENV EXPORTER_HOST=0.0.0.0
ENV EXPORTER_PORT=9090
ENV LOG_LEVEL=INFO
ENV CONFIG_FILE=/app/config/config.yaml

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get(f'http://localhost:{os.environ.get(\"EXPORTER_PORT\", \"9090\")}/metrics')" || exit 1

# Expose port
EXPOSE 9090

# Default command
CMD ["python", "main.py", "run"]