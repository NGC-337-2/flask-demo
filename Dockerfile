# =============================================================
# Stage 1 — builder
# Installs OS build deps and compiles all Python C extensions
# (build-essential, libpq-dev, gcc etc. ONLY exist in this stage)
# =============================================================
FROM python:3.7-slim AS builder

# Prevent .pyc files and ensure logs stream immediately
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /build

# Install OS-level build dependencies (compile-time only — NOT copied to runtime)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip toolchain in its own layer so it is cached independently
RUN pip install --no-cache-dir --upgrade "pip<24" "setuptools<69" wheel "pipenv<2024"

# Copy ONLY the dependency manifests first.
# This layer is cached and only re-built when Pipfile / Pipfile.lock changes.
# Code changes alone will NOT invalidate this layer.
COPY Pipfile Pipfile.lock ./

# Install all production dependencies into the system Python prefix
RUN pipenv sync --system --deploy

# =============================================================
# Stage 2 — runtime
# Lean final image — zero build tools, zero compiler headers
# Only what is needed to *run* the application
# =============================================================
FROM python:3.7-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    FLASK_APP=autoapp.py \
    PORT=5000

WORKDIR /app

# libpq5 is the PostgreSQL *runtime* shared library (~800 KB).
# libpq-dev (compile-time headers) is intentionally NOT installed here.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libpq5 \
    && rm -rf /var/lib/apt/lists/*

# Copy compiled site-packages from the builder stage.
# This brings in psycopg2, bcrypt .so files etc. without any build toolchain.
COPY --from=builder /usr/local/lib/python3.7/site-packages /usr/local/lib/python3.7/site-packages

# Copy CLI entry-points installed by pip (e.g. gunicorn, flask)
COPY --from=builder /usr/local/bin/gunicorn /usr/local/bin/gunicorn
COPY --from=builder /usr/local/bin/flask    /usr/local/bin/flask

# Copy application source LAST — keeps this layer cached on dep-only changes
COPY . .

EXPOSE 5000

# NOTE: Database migrations (flask db upgrade) are intentionally NOT run here.
# Run migrations as a deploy step BEFORE starting the container:
#   docker run --rm --env-file .env <image> flask db upgrade
#
# Or prepend to CMD in docker-compose:
#   command: sh -c "flask db upgrade && gunicorn autoapp:app -b 0.0.0.0:5000 -w 2"
CMD ["gunicorn", "autoapp:app", "-b", "0.0.0.0:5000", "-w", "2", "--timeout", "120"]
