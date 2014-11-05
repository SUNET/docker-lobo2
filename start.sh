#!/bin/sh

export REDIS_HOST="127.0.0.1"
export REDIS_PORT="6379"
if [ "x${BACKEND_PORT}" != "x" ]; then
   REDIS_HOST=`echo "${BACKEND_PORT}" | sed 's%/%%g' | awk -F: '{ print $2 }'`
   REDIS_PORT=`echo "${BACKEND_PORT}" | sed 's%/%%g' | awk -F: '{ print $3 }'`
fi

cat>config.py<<EOF
REDIS_HOST = $REDIS_HOST
REDIS_PORT = $REDIS_PORT
BASE_URL = $BASE_URL
UPLOAD_FOLDER = "/tmp"
EOF

. $VENV/bin/activate && gunicorn -b :8080 lobo2:app
