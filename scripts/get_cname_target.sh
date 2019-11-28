#!/bin/sh

export CERTBOT_DOMAIN=$1
export VALIDATION_TOKEN=test

# regex from https://stackoverflow.com/a/26850032/1431178
# under cc by-sa 4.0 by Doktor J
echo "${CERTBOT_DOMAIN#\*.}" | grep -P '(?=^.{4,253}$)(^(?:[a-zA-Z0-9](?:(?:[a-zA-Z0-9\-]){0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$)'
if $? -ne 0
then
    echo "Invalid domain specified"
    exit 1
fi

echo "Running ACME DNS registration script..."
result=$(/scripts/acme-dns-auth.py)

domain=$(jq -r '.["' + ${CERTBOT_DOMAIN#\*.} + '"].fulldomain' /etc/letsencrypt/acmedns.json)

if [ -z "$result" ]
then
    echo "Old account found. Please add the following CNAME record to your main DNS zone if not already done:"
    echo "_acme-challenge.${CERTBOT_DOMAIN#\*.} CNAME $domain"
else
    echo "$result"
fi