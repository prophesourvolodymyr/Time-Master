#!/bin/sh
set -eu

fail() {
    printf '%s\n' "TimeMaster startup: $*" >&2
    exit 1
}

if [ "$(id -u)" = 0 ]; then
    database=${RANKED_DATABASE:-/data/ranked.sqlite3}
    case "$database" in
        /data/*) ;;
        *) fail 'container RANKED_DATABASE must be an absolute file path under /data' ;;
    esac
    case "$database" in
        *//*|*/./*|*/../*|*/.|*/..|*/) fail 'RANKED_DATABASE contains an unsafe path component' ;;
    esac
    [ ! -L /data ] || fail '/data must not be a symlink'
    mkdir -p /data
    chown 10001:10001 /data
    chmod 0700 /data

    remainder=${database#/data/}
    directory=/data
    while case "$remainder" in */*) true ;; *) false ;; esac; do
        component=${remainder%%/*}
        remainder=${remainder#*/}
        directory=$directory/$component
        [ ! -L "$directory" ] || fail 'database parent must not be a symlink'
        if [ ! -e "$directory" ]; then mkdir "$directory"; fi
        [ -d "$directory" ] || fail 'database parent is not a directory'
        chown 10001:10001 "$directory"
        chmod 0700 "$directory"
    done
    for file in "$database" "$database-wal" "$database-shm"; do
        [ ! -L "$file" ] || fail 'database files must not be symlinks'
        if [ -e "$file" ]; then
            [ -f "$file" ] || fail 'database path is not a regular file'
            chown 10001:10001 "$file"
            chmod 0600 "$file"
        fi
    done
    exec gosu 10001:10001 "$@"
fi

exec "$@"
