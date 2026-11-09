# shellcheck shell=bash
site=$1
read -r -a args <<< "${SSH_ORIGINAL_COMMAND:-}"
dir="$SITES_DIR/$site"

fail() {
  echo "$*" >&2
  exit 1
}

# Checks the command has exactly the expected number of arguments.
check_args() {
  [[ ${#args[@]} -eq $1 ]] || fail "usage: $2"
}

# Checks a sandbox number.
check_sandbox_number() {
  [[ "$1" =~ ^[0-9]+$ ]] || fail "bad sandbox number: $1"
}

# Fetches a build of the site and checks it is plain files.
fetch_and_check_build() {
  local path=$1

  # Checks it is a store path.
  [[ "$path" =~ ^/nix/store/[a-z0-9]{32}-[A-Za-z0-9+._?=-]+$ ]] || fail "bad store path: $path"

  # Checks it is a build of this site.
  [[ "${path#/nix/store/*-}" == "$site" ]] || fail "not a build of $site: $path"

  # Fetches the build, rooted until the script exits.
  pending="$dir/.pending-$$"
  trap 'rm -f "$pending"' EXIT
  nix-store --realise "$path" --add-root "$pending" >/dev/null

  # Checks it references no other store paths.
  local references
  references=$(nix-store --query --references "$path")
  [[ -z "$references" || "$references" == "$path" ]] || fail "not a build of $site: $path has references"

  # Checks it contains no symlinks.
  [[ -z "$(find "$path" -type l -print -quit)" ]] || fail "not a build of $site: $path has symlinks"
}

# Points an environment at a build, keeping its earlier builds as generations.
set_build() {
  local link=$1 path=$2
  nix-env --profile "$link" --set "$path"
  echo "$site ${link#"$dir"/} -> $path"
}

case "${args[0]:-} ${args[1]:-}" in
  "list ")
    check_args 1 "list"
    for link in "$dir"/sandbox/pr-*; do
      if [[ "$link" =~ /pr-([0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]}"
      fi
    done
    ;;
  "current qa" | "current prod")
    check_args 2 "current <qa|prod>"
    readlink -e "$dir/${args[1]}" || fail "${args[1]} has nothing deployed"
    ;;
  "rollback qa" | "rollback prod")
    [[ ${#args[@]} -eq 2 || ${#args[@]} -eq 3 ]] || fail "usage: rollback <qa|prod> [store path]"
    profile="$dir/${args[1]}"
    # Without a build, goes back to the previous generation.
    if [[ ${#args[@]} -eq 2 ]]; then
      nix-env --profile "$profile" --rollback
      echo "$site ${args[1]} -> $(readlink -e "$profile")"
      exit
    fi
    # Finds the newest generation that served the build.
    generation=0
    for link in "$profile"-*-link; do
      n=${link#"$profile"-}
      n=${n%-link}
      if [[ "$n" =~ ^[0-9]+$ && "$(readlink "$link")" == "${args[2]}" ]] && ((n > generation)); then
        generation=$n
      fi
    done
    ((generation > 0)) || fail "${args[1]} never served ${args[2]}"
    nix-env --profile "$profile" --switch-generation "$generation"
    echo "$site ${args[1]} -> ${args[2]}"
    ;;
  "sandbox deploy")
    check_args 4 "sandbox deploy <n> <store path>"
    check_sandbox_number "${args[2]}"
    fetch_and_check_build "${args[3]}"
    set_build "$dir/sandbox/pr-${args[2]}" "${args[3]}"
    ;;
  "sandbox remove")
    check_args 3 "sandbox remove <n>"
    check_sandbox_number "${args[2]}"
    rm -f "$dir/sandbox/pr-${args[2]}" "$dir/sandbox/pr-${args[2]}"-*-link
    ;;
  "qa deploy")
    check_args 3 "qa deploy <store path>"
    fetch_and_check_build "${args[2]}"
    set_build "$dir/qa" "${args[2]}"
    ;;
  "prod deploy")
    check_args 3 "prod deploy <store path>"
    fetch_and_check_build "${args[2]}"
    set_build "$dir/prod" "${args[2]}"
    ;;
  "prod release")
    check_args 2 "prod release"
    build=$(readlink -e "$dir/qa") || fail "qa has nothing deployed"
    set_build "$dir/prod" "$build"
    ;;
  *)
    fail "unknown command: ${SSH_ORIGINAL_COMMAND:-}"
    ;;
esac
