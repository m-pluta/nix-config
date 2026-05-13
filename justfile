default:
    @just --list

# Build and deployment
check:
    nix flake check

build:
    nixos-rebuild build --flake .#mikelab

test:
    nixos-rebuild test --flake .#mikelab --target-host mikelab --sudo

deploy:
    nixos-rebuild switch --flake .#mikelab --target-host mikelab --sudo

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
