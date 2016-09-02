#!/bin/dumb-init /bin/sh
set -e
# allow the container to be started with `--user`
if [ "$1" = 'start-zk' -a "$(id -u)" = '0' ]; then
	  exec gosu zk "$@"
else
    exec "$@"
fi
