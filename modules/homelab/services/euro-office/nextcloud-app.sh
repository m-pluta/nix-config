# shellcheck shell=bash
# Installs the Euro-Office app from the app store, if it is not there yet.
if ! nextcloud-occ app:getpath eurooffice >/dev/null 2>&1; then
  nextcloud-occ app:install eurooffice
fi
nextcloud-occ app:enable eurooffice

nextcloud-occ config:app:set eurooffice DocumentServerUrl --value="$DOCUMENT_SERVER_URL"
nextcloud-occ config:app:set eurooffice StorageUrl --value="$NEXTCLOUD_URL"
# occ prints the value it sets, so its output does not go to the journal.
nextcloud-occ config:app:set eurooffice jwt_secret --value="$(< "$CREDENTIALS_DIRECTORY/jwt")" >/dev/null
