# TODO

- [ ] Standardise `hl`/`cfg` variable naming across modules
- [ ] Add Kanidm for SSO (replaces Keycloak)
- [ ] Set up backup strategy (restic or alternative)
- [ ] Centralise tmpfiles `Z` rules for ZFS-backed services
- [ ] Remove paperless test skip overlay once upstream fixes it
- [ ] Enable "Above 4G Decoding" in BIOS for GPU
- [ ] Enable and configure forgejo-runner
- [ ] Review Attic dataset and CI nix-store volume growth, bound them if needed
- [ ] Add back tailscale IPs for hosts

## Ingress hardening (before Kanidm forward-auth)

- [ ] Support HTTPS upstreams in `mkReverseProxy` (Kanidm only serves TLS)
- [ ] If mikeway ever needs its own DNS (containers or loopback): bind 127.0.0.1, add podman view + port 53 on podman interface to split-dns
