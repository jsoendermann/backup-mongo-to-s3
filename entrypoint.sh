#!/bin/bash

set -e

echo "Backup script version 3"

echo "Installing crontab..."
echo "Schedule: ${CRON_SCHEDULE}"

REQUIRED_ENV_VARS=(
    CRON_SCHEDULE
    MONGO_HOST
    MONGO_USERNAME
    MONGO_PASSWORD
    MONGO_DB
    AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY
    AWS_BUCKET_NAME
    ENCRYPTION_KEY
)

# Make sure all required env vars are there
for var in "${REQUIRED_ENV_VARS[@]}" ; do
    if [[ -z "${!var}" ]] ; then
        echo "$var is not set"
        exit -1
    fi
done

# Set default values for non-required vars
export MONGO_PORT=${MONGO_PORT:-27017}
export MONGO_AUTH_DB=${MONGO_AUTH_DB:-admin}
export FILENAME_PREFIX=${FILENAME_PREFIX:-backup}

# Write crontab
echo -e "\
$(env)\n\
$CRON_SCHEDULE /scripts/backup.sh >> /var/log/cron.log 2>&1\
" | crontab -

echo "Done installing crontab"

# Start cron
cron

# Wait for db to come online
for i in {1..10}; do
    echo "Trying to connect to db..."
    mongo \
        --username "$MONGO_USERNAME" \
        --password "$MONGO_PASSWORD" \
        --authenticationDatabase "$MONGO_AUTH_DB" \
        "${MONGO_HOST}:${MONGO_PORT}" \
        --eval "db.runCommand({ connectionStatus: 1 })" && break
    echo "Unsuccessful. Sleeping..."
    sleep 10
done

# Run the backup once now (useful for debugging)
if [[ -z "$BACK_UP_ON_STARTUP" ]]; then
    echo "Skipping backup on startup"
else
    /scripts/backup.sh
fi

# We have to touch this file to make sure it exists when we run tail
touch /var/log/cron.log

# This is to prevent our container from exiting
tail -f /var/log/cron.log