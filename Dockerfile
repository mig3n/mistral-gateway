# mistral-gateway — a single-file, stdlib-only Python gateway.
#
# Build:
#   docker build -t mistral-gateway .
# Run (state persists in the named volume mounted over /app):
#   docker run -d --name mistral-gateway \
#     --restart unless-stopped \
#     -p 8788:8788 \
#     -e VIBE_KEY=your-vibe-key \
#     -v mistral-gateway-state:/app \
#     mistral-gateway
# --restart unless-stopped starts the container with Docker.
# GATEWAY_KEY is optional: if omitted, docker-entrypoint.sh generates a strong
# random key, saves it to /app/gateway.key in the state volume, and prints it
# once in the logs on first start.
FROM python:3.12-slim

# The app is pure standard library (Python 3.10+), so no apt packages or
# pip installs are needed.
WORKDIR /app

# Copy only the gateway and the entrypoint. Everything else in the build
# context is excluded via .dockerignore (docs, examples, assets, state files,
# service units).
COPY gateway.py /app/
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# Run as a non-root user so the container is safe by default and the state
# files it writes (pool_state.json, usage.db, gateway.key) are not owned by
# root.
RUN useradd --create-home --uid 1000 --shell /usr/sbin/nologin gateway \
    && chown -R gateway:gateway /app \
    && chmod +x /usr/local/bin/docker-entrypoint.sh
USER gateway

# Listen on all interfaces inside the container; the published host port
# mapping (and GATEWAY_KEY) decides who can actually reach it.
ENV BIND=0.0.0.0 \
    PORT=8788

EXPOSE 8788

# /health answers 200 without auth, so this needs no curl — urllib is stdlib.
# An unreachable or failing gateway makes python exit non-zero (unhealthy).
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD ["python3", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8788/health', timeout=4)"]

# The entrypoint generates/persists GATEWAY_KEY when it is unset, then execs
# the gateway so signals and PID semantics are preserved.
ENTRYPOINT ["docker-entrypoint.sh"]
