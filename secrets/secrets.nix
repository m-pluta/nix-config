let
  michal = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINe+skoB2pgfMgyvHY0XRc/ki+8X7eTxzWzPH/DDrTaj mikey@mikebook";
  mikelab = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBi0Jv3D/hErShkePfS3LfX66NRRJMlZ8TnhmjeEocVt root@mikelab";

  admins = [ michal ];
in
{
  # Network / system
  "wifi.age".publicKeys = admins ++ [ mikelab ];
  "cloudflare-dns-api.age".publicKeys = admins ++ [ mikelab ];

  # Users
  "users/michal.age".publicKeys = admins ++ [ mikelab ];

  # Services
  "services/jellyfin/api-key.age".publicKeys = admins ++ [ mikelab ];
  "services/jellyfin/admin-password.age".publicKeys = admins ++ [ mikelab ];

  "services/sonarr/api-key.age".publicKeys = admins ++ [ mikelab ];
  "services/sonarr/password.age".publicKeys = admins ++ [ mikelab ];

  "services/radarr/api-key.age".publicKeys = admins ++ [ mikelab ];
  "services/radarr/password.age".publicKeys = admins ++ [ mikelab ];

  "services/prowlarr/api-key.age".publicKeys = admins ++ [ mikelab ];
  "services/prowlarr/password.age".publicKeys = admins ++ [ mikelab ];
}
