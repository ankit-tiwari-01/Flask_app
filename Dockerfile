# Stage 1: Build dependencies
FROM python:3.11-slim as builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Stage 2: Final lightweight image
FROM python:3.11-slim

WORKDIR /app

COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY . .

# Expose Gunicorn's port
EXPOSE 8080

# Run container as a non-privileged user for security
RUN useradd -m appuser && chown -R appuser:appuser /app
USER appuser

# Health check using Python's standard library (no curl needed)
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')"

ENV FLASK_ENV=production
ENV PORT=8080

# Start Gunicorn serving the application object from application.py
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "4", "application:application"]
