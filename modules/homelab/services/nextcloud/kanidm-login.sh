# shellcheck shell=bash
# Adds Nextcloud's Kanidm provider, or updates it if it already exists.
# With --unique-uid=0, the Nextcloud user ID is the plain username. The default is a hashed ID.
nextcloud-occ user_oidc:provider kanidm \
  --clientid="$CLIENT_ID" \
  --clientsecret="$(< "$CREDENTIALS_DIRECTORY/kanidm-secret")" \
  --discoveryuri="$DISCOVERY_URL" \
  --scope="openid email profile" \
  --unique-uid=0 \
  --mapping-uid=preferred_username \
  --mapping-display-name=name \
  --mapping-email=email
