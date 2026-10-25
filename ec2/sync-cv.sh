#!/bin/bash
set -u
BUCKET="cv-22l-7922"
ROOT="/var/www/html"
LOG="/var/log/cv-sync.log"
TOKEN=$(curl -fsS --max-time 3 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600") || TOKEN=""
INSTANCE_ID=$(curl -fsS --max-time 3 -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id) || INSTANCE_ID=""
if [[ -z "$INSTANCE_ID" ]]; then
  echo "$(date -Is) FAILED: metadata unavailable" >> "$LOG"; exit 1
fi
mkdir -p "$ROOT"
if aws s3 sync "s3://${BUCKET}/site/" "$ROOT/" --delete; then
  if [[ -f "$ROOT/index.html" ]]; then
    sed -i "s/{{HOSTED_ON}}/EC2 ${INSTANCE_ID}/g" "$ROOT/index.html"
    echo "$(date -Is) OK: synced ${INSTANCE_ID}" >> "$LOG"
  else
    echo "$(date -Is) FAILED: missing index.html" >> "$LOG"; exit 1
  fi
else
  echo "$(date -Is) FAILED: S3 sync" >> "$LOG"; exit 1
fi
