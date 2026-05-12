let
  # Users (people who edit secrets from their laptops)
  michal = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINe+skoB2pgfMgyvHY0XRc/ki+8X7eTxzWzPH/DDrTaj mikey@mikebook";

  # Hosts (machines that decrypt secrets at activation)
  mikelab = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBi0Jv3D/hErShkePfS3LfX66NRRJMlZ8TnhmjeEocVt root@mikelab";

  # Groups
  admins = [ michal ];
  allHosts = [ mikelab ];
in
{
  "wifi.age".publicKeys = admins ++ allHosts;
  "users/michal.age".publicKeys = admins ++ allHosts;
}
