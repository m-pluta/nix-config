{ keys, ... }:
{
  # Root-equivalent through wheel.
  users = {
    users.deploy = {
      isNormalUser = true;
      group = "deploy";
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [ keys.deploy.hosts ];
    };
    groups.deploy = { };
  };
}
