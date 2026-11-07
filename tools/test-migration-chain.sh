#!/usr/bin/env bash
set -euo pipefail

red_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
selection=${1:-SQLite}
modes=${RED_CHAIN_MODES:-"0 1"}
if [[ "$selection" == all ]]; then
    drivers=(SQLite Pg MySQL)
else
    drivers=("$selection")
fi

cd "$red_root"
for driver in "${drivers[@]}"; do
    case "$driver" in
        SQLite) connection=SQLite ;;
        Pg) connection=${RED_CHAIN_PG_DATABASE:-${RED_DATABASE:-}} ;;
        MySQL) connection=${RED_CHAIN_MYSQL_DATABASE:-${RED_DATABASE:-}} ;;
        *) echo "Usage: $0 [SQLite|Pg|MySQL|all]" >&2; exit 2 ;;
    esac
    if [[ "${connection%% *}" != "$driver" ]]; then
        echo "Configure RED_DATABASE (or RED_CHAIN_PG_DATABASE / RED_CHAIN_MYSQL_DATABASE) for $driver." >&2
        exit 2
    fi
    for frontend in $modes; do
        case "$frontend" in 0|1) ;; *) echo "RED_CHAIN_MODES accepts 0 and 1." >&2; exit 2 ;; esac
        echo "Testing migration flows: driver=$driver RakuAST=$frontend"
        RAKUDO_RAKUAST=$frontend RED_DATABASE=$connection \
            prove6 -Ilib -v t/147-synchronous-migrations.rakutest \
                t/154-migration-five-levels.rakutest \
                t/155-migration-publication-recovery.rakutest \
                t/156-migration-resolve.rakutest \
                t/157-migration-diamond.rakutest \
                t/158-migration-adoption-serialize.rakutest
    done
done
