#!/bin/sh
# docker-entrypoint.sh — make sure GATEWAY_KEY is set before starting the gateway.
#
# - If GATEWAY_KEY is already in the environment it is used as-is and never
#   echoed (it is the owner's secret).
# - Otherwise a strong random key is generated with python3, persisted to
#   /app/gateway.key (the state volume) so it stays stable across restarts,
#   and printed once so the owner can configure clients.
# - The key is only printed on first start; later it can be re-read from the
#   container logs.
# - If /app is missing or not writable, the key is printed and the container
#   still starts without persisting (best effort, never crash).
#
# Ends by exec'ing the gateway so signals and PID semantics are preserved.

set -eu

if [ -n "${GATEWAY_KEY:-}" ]; then
    # Owner provided a key explicitly: use it, never print it.
    :
elif [ -f /app/gateway.key ]; then
    # A key was generated on a previous start: reuse it so clients keep working.
    GATEWAY_KEY="$(cat /app/gateway.key)"
else
    GATEWAY_KEY="$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')"
    if printf '%s\n' "$GATEWAY_KEY" > /app/gateway.key 2>/dev/null; then
        echo "GATEWAY_KEY=$GATEWAY_KEY generated and saved to /app/gateway.key"
    else
        echo "WARNING: could not write /app/gateway.key (volume missing or not writable); key will not persist across restarts."
        echo "GATEWAY_KEY=$GATEWAY_KEY generated (not persisted)"
    fi
    echo "Hint: your client must send this key as 'Authorization: Bearer <key>'."
    echo "You can read it again later from the container logs (docker logs mistral-gateway / docker compose logs gateway)."
fi

export GATEWAY_KEY
exec python3 gateway.py
