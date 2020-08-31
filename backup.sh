#!/bin/bash

echo "===================> Starting backup at $(date)... <==================="

(
  set -e

  # Files & dirs
  BACKUP_DIR="/tmp-dir"
  DATE=$(date -u "+%F-%H%M%S")
  BACKUP_NAME="${FILENAME_PREFIX}-$DATE"
  ARCHIVE_NAME="$BACKUP_NAME.tar.bz2"
  ARCHIVE_FILE="$BACKUP_DIR/$ARCHIVE_NAME"
  ARCHIVE_FILE_ENC="$BACKUP_DIR/$ARCHIVE_NAME.enc"

  echo "Creating backup dir: ${BACKUP_DIR}"
  mkdir -p "${BACKUP_DIR}"

  # Lock db
  echo "Locking DB"
  mongo \
    --username "$MONGO_USERNAME" \
    --password "$MONGO_PASSWORD" \
    --authenticationDatabase "$MONGO_AUTH_DB" \
    "${MONGO_HOST}:${MONGO_PORT}" \
    --eval "printjson(db.fsyncLock());"

  # Dump db
  echo "Dumping DB"
  mongodump \
    --host "$MONGO_HOST" \
    --port "$MONGO_PORT" \
    --db "$MONGO_DB" \
    --username "$MONGO_USERNAME" \
    --password "$MONGO_PASSWORD" \
    --authenticationDatabase "$MONGO_AUTH_DB" \
    --out "$BACKUP_DIR/$BACKUP_NAME"

  # Unlock db
  echo "Unlocking DB"
  mongo \
    --username "$MONGO_USERNAME" \
    --password "$MONGO_PASSWORD" \
    --authenticationDatabase "$MONGO_AUTH_DB" \
    "${MONGO_HOST}:${MONGO_PORT}" \
    --eval "printjson(db.fsyncUnlock());"

  # Zip dump
  echo "Creating archive"
  tar -C "$BACKUP_DIR/" -jcvf "$ARCHIVE_FILE" "$BACKUP_NAME/"

  # Encrypt archive
  # decrypt with `/usr/local/opt/openssl/bin/openssl enc -aes-256-cbc -md sha512 -pbkdf2 -iter 100000 -salt -d -in "$ARCHIVE_FILE" -k "$ENCRYPTION_KEY" -out "$OUT_FILE"`
  echo "Encrypting"
  openssl enc -aes-256-cbc -md sha512 -pbkdf2 -iter 100000 -salt -in "$ARCHIVE_FILE" -k "$ENCRYPTION_KEY" -out "$ARCHIVE_FILE_ENC"

  # Upload
  echo "Uploading"
  aws s3 cp "$ARCHIVE_FILE_ENC" "s3://${AWS_BUCKET_NAME}/"
)
if [[ $? != 0 ]]; then
  (>&2 echo "An error occurred while backing up the db!")
fi

echo "Deleting temp dir contents..."
rm -rfv "$BACKUP_DIR/*"

echo "===================> Backup complete! <==================="
echo ""