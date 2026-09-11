#!/usr/bin/env bash
# Regenerate .env from .env.example + local overrides, after each upstream pull.
# Overrides (real IPs, ports, etc.) live outside the repo — never committed here.
set -euo pipefail
cd "$(dirname "$0")/.."

CONF_DIR="${GLM53_ENV_LOCAL:-$HOME/.config/local-ai/glm53-flash-exl3}"
OVERRIDES="$CONF_DIR/overrides.env"
BASELINE="$CONF_DIR/baseline.env.example"

[ -f "$OVERRIDES" ] || { echo "ERROR: no overrides file at $OVERRIDES" >&2; exit 1; }

assign_lines() { grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$1" 2>/dev/null || true; }

# Warn only for keys we override whose upstream default line actually changed
# (comment-only edits in .env.example are ignored).
if [ -f "$BASELINE" ]; then
    changed_keys=$(comm -13 \
        <(assign_lines "$BASELINE" | sort) \
        <(assign_lines .env.example | sort) \
        | cut -d= -f1 | sort -u)
    while IFS='=' read -r key _; do
        [ -z "$key" ] && continue
        if grep -qx "$key" <<<"$changed_keys"; then
            echo "WARN: upstream changed default for $key — review your override:" >&2
            grep "^${key}=" "$BASELINE" .env.example | sed 's/^/  /' >&2
        fi
    done < "$OVERRIDES"
fi

cp .env.example .env
while IFS= read -r line; do
    [ -z "$line" ] && continue
    key="${line%%=*}"
    if grep -q "^${key}=" .env; then
        sed -i "s|^${key}=.*|${line//\\/\\\\}|" .env
    else
        printf '%s\n' "$line" >> .env
    fi
done < "$OVERRIDES"

cp .env.example "$BASELINE"
echo "wrote .env from .env.example + $OVERRIDES"
