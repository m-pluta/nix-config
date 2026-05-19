{ config, inputs, ... }:
{
  age.secrets.user-password-michal.file = "${inputs.mikelab-secrets}/users/michal.age";

  users.users.michal = {
    isNormalUser = true;
    description = "Michal";
    hashedPasswordFile = config.age.secrets.user-password-michal.path;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINe+skoB2pgfMgyvHY0XRc/ki+8X7eTxzWzPH/DDrTaj mikey@mikebook"
    ];
  };

  users.users.root.hashedPassword = "!";
  security.sudo.wheelNeedsPassword = false;
  users.mutableUsers = false;
}
