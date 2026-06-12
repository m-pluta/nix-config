update input="":
  nix flake update {{ input }}

check:
  nix flake check

dry-activate host:
  nixos-rebuild-ng dry-activate --flake .#{{host}} --target-host {{host}} --sudo

test host:
  nixos-rebuild-ng test --flake .#{{host}} --target-host {{host}} --sudo

boot host:
  nixos-rebuild-ng boot --flake .#{{host}} --target-host {{host}} --sudo

switch host:
  nixos-rebuild-ng switch --flake .#{{host}} --target-host {{host}} --sudo

reboot host:
  ssh {{host}} sudo reboot

shutdown host:
  ssh {{host}} sudo shutdown now
