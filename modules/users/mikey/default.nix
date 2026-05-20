{ config, inputs, ... }:
{
  nix.settings.trusted-users = [ "mikey" ];

  users = {
    mutableUsers = false;
    users = {
      mikey = {
        uid = 1000;
        isNormalUser = true;
        hashedPasswordFile = config.age.secrets.user-password-mikey.path;
        extraGroups = [
          "wheel"
          "users"
        ];
        group = "mikey";
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINe+skoB2pgfMgyvHY0XRc/ki+8X7eTxzWzPH/DDrTaj mikey@mikebook"
        ];
      };
    };
    groups = {
      mikey = {
        gid = 1000;
      };
    };
  };

  age.secrets.user-password-mikey.file = "${inputs.secrets}/users/mikey.age";
}
