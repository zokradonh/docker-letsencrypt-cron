#!/bin/ash

set -e

umask 077
cat "$RENEWED_LINEAGE/fullchain.pem" "$RENEWED_LINEAGE/privkey.pem" > "$RENEWED_LINEAGE/privfullchain.pem"
echo "new" > "$RENEWED_LINEAGE/new.event"
