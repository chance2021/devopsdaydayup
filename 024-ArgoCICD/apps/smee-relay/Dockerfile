FROM node:20-alpine

RUN apk add --no-cache tini \
    && addgroup -S smee && adduser -S -G smee -h /home/smee smee \
    && npm install --global smee-client \
    && printf '#!/bin/sh\nset -euo pipefail\nif [ -z "${SMEE_URL:-}" ]; then\n  echo "SMEE_URL is required" >&2\n  exit 1\nfi\nTARGET="${SMEE_TARGET:-http://127.0.0.1:12000/payload}"\nexec smee --url "$SMEE_URL" --target "$TARGET"\n' >/entrypoint.sh \
    && chmod +x /entrypoint.sh

USER smee
WORKDIR /home/smee

ENV SMEE_TARGET=http://127.0.0.1:12000/payload

ENTRYPOINT ["/sbin/tini","--","/entrypoint.sh"]
