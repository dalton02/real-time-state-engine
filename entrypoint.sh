#!/bin/sh
set -e

KEY_LENGTH=${KEY_LENGTH:-64} 
RANDOM_KEY=$(openssl rand -base64 $((KEY_LENGTH * 3 / 4 + 1)) | tr -d '\n' | cut -c1-$KEY_LENGTH)


export SECRET_KEY_BASE="$RANDOM_KEY"
export DATABASE_PATH=/app/data/app.db

/app/bin/app eval "App.Release.migrate()"
/app/bin/app eval "App.Release.seed()"

echo "==> Iniciando aplicação..."



export PHX_SERVER=true

exec /app/bin/app start