#!/bin/ash

echo "Trying to install or update certificates"
/usr/bin/issue

echo "Starting cron in foreground"
exec crond -f
