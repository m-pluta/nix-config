{ config, inputs, ... }:
{
  nix.settings.trusted-users = [ "michal" ];

  users = {
    mutableUsers = false;
    users = {
      michal = {
        uid = 1000;
        isNormalUser = true;
        hashedPasswordFile = config.age.secrets.user-password-michal.path;
        extraGroups = [
          "wheel"
          "users"
        ];
        group = "michal";
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINe+skoB2pgfMgyvHY0XRc/ki+8X7eTxzWzPH/DDrTaj mikey@mikebook"
        ];
      };
      root.hashedPassword = "!";
    };
    groups = {
      michal = {
        gid = 1000;
      };
    };
  };

  security.sudo.wheelNeedsPassword = false;
  age.secrets.user-password-michal.file = "${inputs.mikelab-secrets}/users/michal.age";
}
