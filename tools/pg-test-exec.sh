#!/usr/bin/env bash
set -euo pipefail

if (( $# != 1 )); then
    echo "Usage: $0 TEST_FILE" >&2
    exit 2
fi

source_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
export PGHOST=${PGHOST:-127.0.0.1}
export PGPORT=${PGPORT:-5432}
export PGUSER=${PGUSER:-postgres}
maintenance_db=${PGDATABASE:-postgres}
database="red_pg_test_$$"
database_created=false

cleanup() {
    local status=$?
    if "$database_created"; then
        if dropdb --maintenance-db="$maintenance_db" --if-exists "$database"; then
            :
        else
            local cleanup_status=$?
            echo "Failed to remove PostgreSQL test database $database" >&2
            if (( status == 0 )); then
                status=$cleanup_status
            fi
        fi
    fi
    exit "$status"
}
trap cleanup EXIT

createdb --maintenance-db="$maintenance_db" --template=template0 "$database"
database_created=true
export RED_DATABASE="Pg host=$PGHOST port=$PGPORT dbname=$database user=$PGUSER"
raku "-I$source_root/lib" "$1"
