# syntax=docker/dockerfile:1

FROM python:3.12-slim@sha256:05cda9777409a9c3ffddd94a4c476b79f0769a0b4857f0c7ed9226b6800b0d6f AS builder

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /build

COPY app/requirements.txt .

RUN pip wheel --no-cache-dir --wheel-dir=/wheels -r requirements.txt


FROM python:3.12-slim@sha256:05cda9777409a9c3ffddd94a4c476b79f0769a0b4857f0c7ed9226b6800b0d6f AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PORT=8080

RUN groupadd --system app \
    && useradd --system --gid app --home-dir /app \
        --no-create-home --shell /usr/sbin/nologin app

WORKDIR /app

COPY --from=builder /wheels /wheels

RUN pip install --no-index --find-links=/wheels /wheels/* \
    && rm -rf /wheels \
    && python -m pip check

COPY --chown=app:app app/ ./app/

USER app:app

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/healthz', timeout=2)"]

CMD ["gunicorn", "--chdir", "app", "--bind", "0.0.0.0:8080", "--workers", "2", "app:app"]