#!/bin/sh
# Attach build traces to a sticky PR comment and link each one in the trace viewers.
#
# Usage: post-build-traces.sh <dir of build-trace-<host>.json files>
# Needs TOKEN, PR and TRACES (the traces service URL), plus the GITHUB_API_URL and
# GITHUB_REPOSITORY that CI sets.
set -eu

dir="$1"
marker="<!-- build-traces -->"
api="${GITHUB_API_URL}/repos/${GITHUB_REPOSITORY}"
auth="Authorization: token $TOKEN"
jq() { nix run nixpkgs#jq -- "$@"; }

id="$(curl -sSf -H "$auth" "$api/issues/$PR/comments?limit=50" |
	jq -r --arg m "$marker" 'map(select(.body | startswith($m))) | .[0].id // empty')"
if [ -z "$id" ]; then
	id="$(curl -sSf -X POST -H "$auth" -H "Content-Type: application/json" \
		-d "$(jq -n --arg b "$marker" '{body: $b}')" "$api/issues/$PR/comments" |
		jq -r .id)"
fi

# Keep only this run's traces on the comment.
curl -sSf -H "$auth" "$api/issues/comments/$id/assets" |
	jq -r '.[] | select(.name | startswith("build-trace-")) | .id' |
	while read -r asset; do
		curl -sSf -X DELETE -H "$auth" "$api/issues/comments/$id/assets/$asset"
	done

body="$marker
### Build traces
"
found=
for f in "$dir"/build-trace-*.json; do
	[ -e "$f" ] || continue
	found=1
	name="$(basename "$f")"
	host="${name#build-trace-}"
	host="${host%.json}"
	uuid="$(curl -sSf -H "$auth" -F "attachment=@$f" \
		"$api/issues/comments/$id/assets?name=$name" | jq -r .uuid)"
	trace="$TRACES/attachments/$uuid"
	body="$body
- **$host**: [Perfetto]($TRACES/perfetto/#!/?url=$trace) · [Speedscope]($TRACES/speedscope/#profileURL=$trace)"
done
[ -n "$found" ] || body="$body
No traces were recorded."

curl -sSf -X PATCH -H "$auth" -H "Content-Type: application/json" \
	-d "$(jq -n --arg b "$body" '{body: $b}')" "$api/issues/comments/$id" >/dev/null
echo "Updated build traces comment #$id."
