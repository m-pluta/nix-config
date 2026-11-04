# Evaluate and build on mikelab by default; BUILD_HOST= does both locally
build_host := env("BUILD_HOST", "mikelab")

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
