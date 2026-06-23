# Flask Docker Deployment Notes

Date: 2026-06-23
Project: flask-demo (fork of https://github.com/gothinkster/flask-realworld-example-app)

## 1) Repository/Fork Setup

This workspace was already connected to the fork as `origin`.

```bash
git remote -v
```

Configured upstream to original open-source repository:

```bash
git remote add upstream https://github.com/gothinkster/flask-realworld-example-app.git
git remote -v
```

## 2) Dockerfile Used

```dockerfile
FROM python:3.7-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    FLASK_APP=autoapp.py \
    FLASK_DEBUG=1 \
    PORT=5000

WORKDIR /app

# Build dependencies for packages like psycopg2/bcrypt.
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY Pipfile Pipfile.lock ./

RUN pip install --no-cache-dir --upgrade "pip<24" wheel "pipenv==2023.10.3" \
    && pip install --no-cache-dir --upgrade "setuptools<46" \
    && pipenv install --system

COPY . .

# Initialize SQLite schema in the image for a simple local demo run.
RUN flask db init \
    && flask db migrate -m "initial migration" \
    && flask db upgrade

EXPOSE 5000

CMD ["gunicorn", "autoapp:app", "-b", "0.0.0.0:5000", "-w", "2"]
```

## 3) Build and Run Commands

```bash
docker build -t flask-demo:local .
docker run --name flask-demo-app -p 5000:5000 -d flask-demo:local
docker logs --tail 100 flask-demo-app
curl.exe -s http://localhost:5000/api/tags
```

## 4) Browser Verification

Checked endpoint:

```text
http://localhost:5000/api/tags
```

Observed response:

```json
{"tags": []}
```

Browser check was completed at:

```text
http://localhost:5000/api/tags
```

## 5) Problems Faced and Resolutions

1. Legacy Python/Flask dependency compatibility risk.
    - Resolution: used `python:3.7-slim`, installed packages from `Pipfile.lock`, pinned `pipenv==2023.10.3`, and downgraded setuptools to `<46` to support old packages like `MarkupSafe==1.0`.

2. Database tables are needed before querying API routes.
   - Resolution: executed `flask db init`, `flask db migrate`, and `flask db upgrade` during image build so `/api/tags` works immediately after container startup.

3. Original repo/fork relationship needed explicit tracking.
   - Resolution: configured `upstream` remote to the original open-source repository.

4. PowerShell `curl` alias prompted interactively (web script warning).
    - Resolution: used `curl.exe` for non-interactive command-line verification.
