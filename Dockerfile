ARG PYTHON_VERSION="3.8.13-slim-bullseye"
ARG NODE_VERSION="18.20-bullseye-slim"

# Frontend builder stage
FROM node:${NODE_VERSION} AS frontend-builder

COPY frontend/ /frontend/
WORKDIR /frontend
ENV PUBLIC_PATH="/static/_nuxt/"

# hadolint ignore=DL3008
RUN apt-get update \
 && apt-get install -y --no-install-recommends git python3 make g++ ca-certificates \
 && git config --global url."https://github.com/".insteadOf git://github.com/ \
 && yarn install --network-timeout 1000000 \
 && yarn build \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Backend builder stage
FROM python:3.8.13-slim-bullseye AS backend-builder

# Install system dependencies for building Python packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    g++ \
    libpq-dev \
    unixodbc-dev \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

# Install dependencies directly without Poetry
RUN pip install -U --no-cache-dir pip==22.2.2 && \
    pip install --no-cache-dir \
    django==4.0.4 \
    djangorestframework==3.14.0 \
    django-cors-headers==3.13.0 \
    django-filter==22.1 \
    django-polymorphic==3.1.0 \
    django-rest-polymorphic==0.1.10 \
    dj-database-url==1.0.0 \
    psycopg2-binary==2.8.6 \
    django-heroku==0.3.1 \
    gunicorn==20.1.0 \
    whitenoise==6.2.0 \
    celery==5.2.7 \
    redis==4.3.4 \
    requests==2.28.1 \
    Pillow==9.2.0 \
    python-decouple==3.6 \
    django-widget-tweaks==1.4.12 \
    auto-labeling-pipeline==0.1.21 \
    chardet==5.0.0 \
    pyexcel==0.7.0 \
    pyexcel-xlsx==0.6.0 \
    seqeval==1.2.2 \
    pandas==1.4.3 \
    numpy==1.21.6 \
    environs==9.5.0 \
    django-extensions==3.2.0 \
    django-debug-toolbar==3.2.4 \
    django-allauth==0.51.0 \
    social-auth-app-django==5.0.0

# Runtime stage
FROM python:${PYTHON_VERSION} AS runtime

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    libpq-dev=13.* \
    unixodbc-dev=2.* \
    libssl-dev=1.* \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

RUN useradd -ms /bin/sh doccano
RUN mkdir /data \
 && chown doccano:doccano /data

COPY --from=backend-builder /usr/local/lib/python3.8/site-packages /usr/local/lib/python3.8/site-packages
COPY --from=backend-builder /usr/local/bin/celery /usr/local/bin/celery
COPY --from=backend-builder /usr/local/bin/gunicorn /usr/local/bin/gunicorn

COPY --chown=doccano:doccano . /doccano
WORKDIR /doccano/backend
COPY --from=frontend-builder /frontend/dist /doccano/backend/client/dist
RUN python manage.py collectstatic --noinput \
 && chown -R doccano:doccano .

VOLUME /data

# Environment variables for Render deployment
ENV DEBUG="False"
ENV STANDALONE="True"
ENV SECRET_KEY="change-me-in-production"
ENV PORT="8000"
ENV WORKERS="2"
ENV CELERY_WORKERS="2"
ENV GOOGLE_TRACKING_ID=""
ENV DJANGO_SETTINGS_MODULE="config.settings.production"

# Default admin credentials (should be overridden via environment variables)
ENV ADMIN_USERNAME="admin"
ENV ADMIN_PASSWORD="password"
ENV ADMIN_EMAIL="admin@example.com"

# Gmail whitelist environment variable
ENV ALLOWED_GMAIL_DOMAINS="gmail.com"

USER doccano
EXPOSE ${PORT}

CMD ["/doccano/tools/run.sh"]

