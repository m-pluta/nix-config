# Evaluate and build on mikelab by default; BUILD_HOST= does both locally
build_host := env("BUILD_HOST", "mikelab")

identity := home_directory() / ".ssh/id_ed25519"
age_identity := env("AGE_IDENTITY", identity)

update input="":
  nix flake update {{ input }}

check:
  nix flake check

# Regenerate the service list into `out` (default: README.md, edit in place)
readme out="README.md":
  (grep -B 99999 "BEGIN SERVICE LIST" README.md && nix eval --offline --raw --file bin/generateServicesTable.nix && grep -A 99999 "END SERVICE LIST" README.md) > {{out}}.tmp
  mv {{out}}.tmp {{out}}

dry-activate host: (rebuild "dry-activate" host)

test host: (rebuild "test" host)

boot host: (rebuild "boot" host)

switch host: (rebuild "switch" host)

# Copies the flake and its inputs to the build host, which evaluates, builds
# and activates from there
[private]
rebuild action host:
  #!/usr/bin/env bash
  set -euo pipefail
  if [ -z "{{build_host}}" ]; then
    exec nixos-rebuild-ng {{action}} --flake .#{{host}} --target-host {{host}} --sudo
  fi
  src=$(nix flake archive --to ssh-ng://{{build_host}} --json | jq -r .path)
  target="{{ if host == build_host { "" } else { "--target-host " + host } }}"
  ssh -A {{build_host}} nixos-rebuild {{action}} --flake "$src#{{host}}" $target --sudo --option accept-flake-config true

deploy host:
  deploy .#{{host}}

reboot host:
  ssh {{host}} sudo reboot

shutdown host:
  ssh {{host}} sudo shutdown now

# Run a throwaway local Grafana for editing dashboards, with metrics from vm.mpluta.dev
grafana-dev:
  #!/usr/bin/env bash
  set -euo pipefail
  grafana=$(nix build --no-link --print-out-paths --inputs-from . nixpkgs#grafana)
  state=$(mktemp -d)
  trap 'rm -rf "$state"' EXIT
  mkdir -p "$state/plugins" "$state"/provisioning/{alerting,dashboards,datasources,plugins}
  cat >"$state/provisioning/datasources/dev.yaml" <<YAML
  apiVersion: 1
  datasources:
    - name: VictoriaMetrics
      type: prometheus
      url: https://vm.mpluta.dev
      isDefault: true
  YAML
  cat >"$state/provisioning/dashboards/dev.yaml" <<YAML
  apiVersion: 1
  providers:
    - name: nix-config
      updateIntervalSeconds: 3
      allowUiUpdates: true
      options:
        path: $PWD/modules/homelab/services/monitoring/grafana/dashboards
  YAML
  echo "Grafana: http://127.0.0.1:13000/d/storage"
  GF_PATHS_DATA="$state/data" \
    GF_PATHS_LOGS="$state/logs" \
    GF_PATHS_PLUGINS="$state/plugins" \
    GF_PATHS_PROVISIONING="$state/provisioning" \
    GF_SERVER_HTTP_ADDR=127.0.0.1 \
    GF_SERVER_HTTP_PORT=13000 \
    GF_AUTH_ANONYMOUS_ENABLED=true \
    GF_AUTH_ANONYMOUS_ORG_ROLE=Admin \
    GF_LOG_LEVEL=warn \
    "$grafana/bin/grafana" server --homepath "$grafana/share/grafana"

# Run OpenTofu on infra/, e.g. `just infra plan`
infra *args="plan":
  #!/usr/bin/env bash
  set -euo pipefail
  secrets=$(nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).inputs.secrets.outPath')
  decrypt() { age -d -i "{{age_identity}}" "$secrets/$1"; }
  CLOUDFLARE_API_TOKEN=$(decrypt infra/cloudflare/tofu-token.age)
  export CLOUDFLARE_API_TOKEN
  GITLAB_TOKEN=$(decrypt infra/gitlab/tofu-token.age)
  export GITLAB_TOKEN
  for file in "$secrets"/infra/cloudflare/tunnels/*.age; do
    export "TF_VAR_tunnel_secret_$(basename "$file" .age)=$(decrypt "infra/cloudflare/tunnels/$(basename "$file")")"
  done
  passphrase=$(decrypt infra/tofu/state-passphrase.age)
  export TF_ENCRYPTION="
    key_provider \"pbkdf2\" \"state\" {
      passphrase = \"$passphrase\"
    }
    method \"aes_gcm\" \"state\" {
      keys = key_provider.pbkdf2.state
    }
    state {
      method   = method.aes_gcm.state
      enforced = true
    }
    plan {
      method   = method.aes_gcm.state
      enforced = true
    }
  "
  cd infra
  install -m 644 "$(nix build --no-link --print-out-paths ..#infra)" config.tf.json
  tofu init -input=false >/dev/null
  tofu {{args}}
