default:
    @just --list

# Build and deployment
check:
    nix flake check

build:
    nix run nixpkgs#nixos-rebuild -- build --flake .#mikelab

test:
    nix run nixpkgs#nixos-rebuild -- test --flake .#mikelab --target-host mikelab --sudo

deploy:
    nix run nixpkgs#nixos-rebuild -- switch --flake .#mikelab --target-host mikelab --sudo

# Secret management
secret name:
    cd secrets && nix run github:ryantm/agenix -- -e {{ name }}.age

rekey:
    cd secrets && nix run github:ryantm/agenix -- -r

# Helpers
update:
    nix flake update

logs:
    ssh mikelab "journalctl -f"

fmt:
    nix fmt
