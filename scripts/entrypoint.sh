#!/bin/ash

if [[ "$1" == "" ]]; then
  exit
fi

cmd=$1
shift

if [[ "$cmd" == "issue" ]] || [[ "$cmd" == "renew" ]]; then
  python /scripts/getcerts.py "$@"
else
  $cmd "$@"
fi
