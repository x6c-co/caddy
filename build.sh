#!/usr/bin/env bash
#
# Reproducible local build of the custom Caddy binary.
#
# This runs the EXACT same xcaddy invocation as .github/workflows/build.yml, so a
# local build and a CI build of the same versions.env produce the same modules.
#
# Usage:
#   ./build.sh                  # builds ./caddy-linux-amd64
#   ./build.sh /tmp/caddy       # builds to a custom output path
#
# Prerequisites:
#   - Go matching $GO_VERSION in versions.env (>= 1.26.1; see note there)
#   - xcaddy matching $XCADDY_VERSION:
#       go install github.com/caddyserver/xcaddy/cmd/xcaddy@<XCADDY_VERSION>
#
set -euo pipefail

cd "$(dirname "$0")"

# --- Load pinned versions (single source of truth) -------------------------
set -a
# shellcheck disable=SC1091
source versions.env
set +a

# --- Build environment -----------------------------------------------------
# Static, cross-distro binary; linux/amd64 only (the fleet is all amd64).
export CGO_ENABLED=0
export GOOS=linux
export GOARCH=amd64
# Pin the toolchain: a dependency that demands a newer Go should fail loudly
# here rather than silently downloading a different toolchain (which would
# defeat the "pinned, reproducible" guarantee).
export GOTOOLCHAIN=local

# --- Sanity checks ---------------------------------------------------------
if ! command -v xcaddy >/dev/null 2>&1; then
  echo "error: xcaddy not found on PATH." >&2
  echo "       install it with: go install github.com/caddyserver/xcaddy/cmd/xcaddy@${XCADDY_VERSION}" >&2
  exit 1
fi

OUTPUT="${1:-caddy-linux-amd64}"

echo ">> building Caddy ${CADDY_VERSION} -> ${OUTPUT}"
echo ">>   cache-handler          ${CACHE_HANDLER_VERSION}"
echo ">>   storages/redis/caddy   ${STORAGES_REDIS_VERSION}"
echo ">>   caddy-dns/desec        ${DESEC_VERSION}"
echo ">>   coraza-caddy/v2        ${CORAZA_VERSION}"
echo ">>   GOOS=${GOOS} GOARCH=${GOARCH} CGO_ENABLED=${CGO_ENABLED} GOTOOLCHAIN=${GOTOOLCHAIN}"

# --- Build -----------------------------------------------------------------
xcaddy build "${CADDY_VERSION}" \
  --output "${OUTPUT}" \
  --with "github.com/caddyserver/cache-handler@${CACHE_HANDLER_VERSION}" \
  --with "github.com/darkweak/storages/redis/caddy@${STORAGES_REDIS_VERSION}" \
  --with "github.com/caddy-dns/desec@${DESEC_VERSION}" \
  --with "github.com/corazawaf/coraza-caddy/v2@${CORAZA_VERSION}"

echo ">> built ${OUTPUT}"
