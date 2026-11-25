#!/bin/bash
set -euo pipefail
: "${EVY_POSTGRES_HOST:?Dedicated database required}"
: "${EVY_POSTGRES_PASSWORD:?Dedicated database required}"
: "${EVY_SECRET_KEY:?Dedicated application secret required}"
: "${EVY_REDIS_URL:?Dedicated cache required}"
export POSTGRES_HOST="$EVY_POSTGRES_HOST"
export POSTGRES_PORT="$EVY_POSTGRES_PORT"
# Private acceptance only. No public domain, payment credentials, or external email.
export EVY_RUNNING_ENVIRONMENT=production
export EVY_DEBUG=false
export EVY_EMAIL_BACKEND=django.core.mail.backends.dummy.EmailBackend
python manage.py migrate --noinput
python manage.py compilemessages -i .venv
python manage.py updatestyles
celery -A eventyay worker -l warning -Q default,notifications,longrunning,background -c 1 &
worker=$!
celery -A eventyay beat -l warning --scheduler django_celery_beat.schedulers:DatabaseScheduler &
beat=$!
gunicorn eventyay.config.wsgi:application --bind "0.0.0.0:${PORT:-10000}" --worker-class gthread --workers 1 --threads 2 --timeout 60 &
web=$!
trap 'kill "$worker" "$beat" "$web" 2>/dev/null || true' EXIT
wait -n "$worker" "$beat" "$web"
