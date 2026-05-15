default:
    @just --list

# Build and deployment
check:
    nix flake check

build: check
    nixos-rebuild build --flake .#mikelab

dry: check
    nixos-rebuild dry-activate --flake .#mikelab --target-host mikelab --sudo

test: check
    nixos-rebuild test --flake .#mikelab --target-host mikelab --sudo

deploy: check
    nixos-rebuild switch --flake .#mikelab --target-host mikelab --sudo

# kexec into in-RAM installer for offline maintenance
# Uses ethernet IP because the installer image has no wifi or tailscale
mikelab_eth := "192.168.0.107"
kexec:
    test -f /tmp/kexec.tar.gz || curl -L -o /tmp/kexec.tar.gz \
      https://github.com/nix-community/nixos-images/releases/download/nixos-25.05/nixos-kexec-installer-noninteractive-x86_64-linux.tar.gz
    nix run github:nix-community/nixos-anywhere -- \
      --flake .#mikelab \
      --kexec /tmp/kexec.tar.gz \
      --target-host michal@{{ mikelab_eth }} \
      --phases kexec

# ssh as root into the in-RAM installer (after `just kexec`)
kexec-shell:
    ssh root@{{ mikelab_eth }}

# Secret management
secret name:
    cd secrets && agenix -e {{ name }}.age

rekey:
    cd secrets && agenix -r

# Helpers
update:
    nix flake update

logs:
    ssh mikelab "journalctl -f"

fmt:
    nix fmt
