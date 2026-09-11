#!/usr/bin/env bash
# scripts/sync-env.sh: rebuilds .env from .env.example + an out-of-repo
# overrides file, and warns (without blocking) when upstream changes the
# default for a key we override.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../scripts/sync-env.sh"
[ -f "$SCRIPT" ] || { echo "scripts/sync-env.sh not found" >&2; exit 1; }
fail=0

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/repo/scripts" "$WORK/conf"
cp "$SCRIPT" "$WORK/repo/scripts/sync-env.sh"
export GLM53_ENV_LOCAL="$WORK/conf"

write_example() { # $1 = file, rest = KEY=VALUE lines
    local f="$1"; shift
    { echo "# auto-generated comment, reworded every release"; printf '%s\n' "$@"; } > "$f"
}

check() { # $1 label, $2 actual, $3 expected
    if [ "$2" = "$3" ]; then echo "ok   $1"
    else echo "FAIL $1 -> got [$2] want [$3]"; fail=1; fi
}

# ---- case A: first sync, no baseline yet -----------------------------------
write_example "$WORK/repo/.env.example" "HEAD_IP=10.0.0.1" "PORT=8888"
printf 'HEAD_IP=192.168.200.12\nPORT=8000\n' > "$WORK/conf/overrides.env"

out="$("$WORK/repo/scripts/sync-env.sh" 2>"$WORK/err_a")"
check "A wrote .env" "$(grep -c . "$WORK/repo/.env")" "3"
check "A HEAD_IP overridden" "$(grep '^HEAD_IP=' "$WORK/repo/.env")" "HEAD_IP=192.168.200.12"
check "A PORT overridden"    "$(grep '^PORT='    "$WORK/repo/.env")" "PORT=8000"
check "A no warning on first run" "$(cat "$WORK/err_a")" ""
check "A baseline snapshot written" "$(cat "$WORK/conf/baseline.env.example")" "$(cat "$WORK/repo/.env.example")"

# ---- case B: re-sync, upstream only reworded comments -> no warning -------
write_example "$WORK/repo/.env.example" "HEAD_IP=10.0.0.1" "PORT=8888"
sed -i '1s/.*/# a totally different comment this release/' "$WORK/repo/.env.example"
"$WORK/repo/scripts/sync-env.sh" 2>"$WORK/err_b" >/dev/null
check "B no warning on comment-only change" "$(cat "$WORK/err_b")" ""
check "B override still applied" "$(grep '^PORT=' "$WORK/repo/.env")" "PORT=8000"

# ---- case C: upstream changes the default we override -> warns, still applies
write_example "$WORK/repo/.env.example" "HEAD_IP=10.0.0.1" "PORT=9999"
"$WORK/repo/scripts/sync-env.sh" 2>"$WORK/err_c" >/dev/null
case "$(cat "$WORK/err_c")" in
    *"WARN: upstream changed default for PORT"*) echo "ok   C warns on changed upstream default" ;;
    *) echo "FAIL C missing warning: [$(cat "$WORK/err_c")]"; fail=1 ;;
esac
check "C override wins despite upstream change" "$(grep '^PORT=' "$WORK/repo/.env")" "PORT=8000"

# ---- case D: overrides key absent from .env.example -> appended -----------
write_example "$WORK/repo/.env.example" "HEAD_IP=10.0.0.1" "PORT=8888"
printf 'HEAD_IP=192.168.200.12\nPORT=8000\nLIMIT_MM={"image":4,"video":0}\n' > "$WORK/conf/overrides.env"
"$WORK/repo/scripts/sync-env.sh" >/dev/null 2>&1
check "D appends key not in example" "$(grep '^LIMIT_MM=' "$WORK/repo/.env")" 'LIMIT_MM={"image":4,"video":0}'

# ---- case E: missing overrides file -> hard error, non-zero exit ----------
rm -f "$WORK/conf/overrides.env"
if "$WORK/repo/scripts/sync-env.sh" >/dev/null 2>"$WORK/err_e"; then
    echo "FAIL E should exit non-zero when overrides file is missing"; fail=1
else
    echo "ok   E fails closed without an overrides file"
fi

[ "$fail" = 0 ] && echo "sync-env tests: PASS"
exit $fail
