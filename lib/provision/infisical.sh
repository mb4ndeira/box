#!/usr/bin/env bash
# Provision: infisical — pull secrets from Infisical into a .env file.
# Requires: infisical CLI authenticated; INFISICAL_TOKEN or machine identity.

set -euo pipefail

cd "${PROJECT_PATH:?PROJECT_PATH not set}"

if ! command -v infisical &>/dev/null; then
    echo "box: infisical CLI not found — skipping secret pull" >&2
    exit 0
fi

infisical run --silent -- env > .env.infisical
echo "box: secrets written to ${PROJECT_PATH}/.env.infisical"
