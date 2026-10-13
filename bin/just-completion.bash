# shellcheck shell=bash
# Completion for just. It keeps just's own completion (recipe names and options) and adds
# the flake's hosts as the value of any recipe parameter named `host`.

eval "$(JUST_COMPLETE=bash just)"

_just_complete() {
    local i recipe=""
    # The recipe is the first word that is not an option.
    for ((i = 1; i < COMP_CWORD; i++)); do
        if [[ ${COMP_WORDS[i]} != -* ]]; then
            recipe=${COMP_WORDS[i]}
            break
        fi
    done

    # Only the argument straight after the recipe name is a host.
    if [[ -n $recipe ]] && ((i == COMP_CWORD - 1)); then
        local signature
        signature=$(just --show "$recipe" 2>/dev/null | head -n 1)
        if [[ $signature =~ (^|[[:space:]])[*+]?host([=:[:space:]]|$) ]]; then
            # The directory goes in the flake reference, not through cd, which a shell may wrap.
            local dir hosts
            dir=$(dirname "$(just --find 2>/dev/null)")
            hosts=$(nix eval "$dir#nixosConfigurations" --apply builtins.attrNames --json 2>/dev/null | jq -r '.[]')
            compopt +o nospace 2>/dev/null
            mapfile -t COMPREPLY < <(compgen -W "$hosts" -- "${COMP_WORDS[COMP_CWORD]}")
            return
        fi
    fi

    _clap_complete_just "$@"
}

complete -o nospace -o bashdefault -o nosort -F _just_complete just
