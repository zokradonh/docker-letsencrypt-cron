#!/bin/ash

set -e

for domain in $RENEWED_DOMAINS; do
    umask 077
    cat "$RENEWED_LINEAGE/fullchain.pem" "$RENEWED_LINEAGE/privkey.pem" > "$RENEWED_LINEAGE/privfullchain.pem"
done
