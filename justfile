update input="":
  nix flake update {{ input }}

check:
  nix flake check

# Regenerate the service list into `out` (default: README.md, edit in place)
readme out="README.md":
  (grep -B 99999 "BEGIN SERVICE LIST" README.md && nix eval --offline --raw --file bin/generateServicesTable.nix && grep -A 99999 "END SERVICE LIST" README.md) > {{out}}.tmp
  mv {{out}}.tmp {{out}}

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
