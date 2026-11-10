# shellcheck shell=bash
name=${1:?usage: kanidm-invite <name>}

# Keeps the admin session in a temporary folder, removed on exit.
tokens=$(mktemp -d)
trap 'rm -rf "$tokens"' EXIT
export KANIDM_TOKEN_CACHE_PATH=$tokens/tokens

KANIDM_PASSWORD=$(< "$IDM_ADMIN_PASSWORD_FILE")
export KANIDM_PASSWORD
kanidm login -D idm_admin >/dev/null

# A one-time link to set up the person's login, valid for a day.
kanidm person credential create-reset-token "$name" --ttl 86400 -D idm_admin
