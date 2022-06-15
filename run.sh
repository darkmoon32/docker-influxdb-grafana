#!/bin/bash -e

# We need to ensure this directory is writeable on start of the container
chmod 0777 /var/lib/grafana

exec /usr/bin/supervisord &

if [ ! -f /setup_done ]
then
    sleep 3
    source /setup.sh
fi
