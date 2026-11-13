# shellcheck shell=bash
# Writes Paperless's Kanidm provider settings, which include the client secret.
providers=$(jq -cn \
  --arg client_id "$CLIENT_ID" \
  --rawfile secret "$CREDENTIALS_DIRECTORY/kanidm-secret" \
  --arg server_url "$SERVER_URL" \
  '{openid_connect: {OAUTH_PKCE_ENABLED: true, APPS: [{
    provider_id: "kanidm",
    name: "Kanidm",
    client_id: $client_id,
    secret: $secret,
    settings: {server_url: $server_url}
  }]}}')
# New files get mode 600, so only Paperless can read the secret
umask 077
printf "PAPERLESS_SOCIALACCOUNT_PROVIDERS='%s'\n" "$providers" > "$ENV_DIR/env"
