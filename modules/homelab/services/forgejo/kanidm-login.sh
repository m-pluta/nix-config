# shellcheck shell=bash
# Adds Forgejo's Kanidm login source, or updates it if it already exists.
args=(
  --name kanidm
  --provider openidConnect
  --key "$CLIENT_ID"
  --secret "$(< "$CREDENTIALS_DIRECTORY/kanidm-secret")"
  --auto-discover-url "$DISCOVERY_URL"
  --scopes "openid email profile"
  --skip-local-2fa
)

id=$(forgejo admin auth list --vertical-bars | awk -F'|' '{ gsub(/[[:space:]]/, ""); if ($2 == "kanidm") print $1 }')
if [ -n "$id" ]; then
  forgejo admin auth update-oauth --id "$id" "${args[@]}"
else
  forgejo admin auth add-oauth "${args[@]}"
fi
