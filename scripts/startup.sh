#!/bin/ash

echo "Trying to install or update certificates"
python /scripts/getcerts.py

echo "Starting cron in foreground"
crond -f
