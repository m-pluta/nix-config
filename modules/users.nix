{ config, pkgs, ... }:
{
  age.secrets.user-password-michal.file = ../secrets/users/michal.age;

  users.users.michal = {
    isNormalUser = true;
    description = "Michal";
    hashedPasswordFile = config.age.secrets.user-password-michal.path;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINe+skoB2pgfMgyvHY0XRc/ki+8X7eTxzWzPH/DDrTaj mikey@mikebook"
    ];
  };

  # disable root password login entirely, sudo from wheel still works
  users.users.root.hashedPassword = "!";

  # convenience for key-only SSH, threat model assumes shell access = you
  security.sudo.wheelNeedsPassword = false;

  # Nix config is single source of truth, manual useradd/passwd gets wiped
  users.mutableUsers = false;
  environment.shellAliases = {
    useradd = "echo 'WARNING: mutableUsers = false, changes will not persist past rebuild' >&2; useradd";
    passwd = "echo 'WARNING: mutableUsers = false, changes will not persist past rebuild' >&2; passwd";
    usermod = "echo 'WARNING: mutableUsers = false, changes will not persist past rebuild' >&2; usermod";
    userdel = "echo 'WARNING: mutableUsers = false, changes will not persist past rebuild' >&2; userdel";
  };
  users.motd = ''
    This system is managed declaratively (mutableUsers = false).
    Changes via useradd/passwd/usermod will not persist past a rebuild.
    Edit modules/users.nix and rebuild instead.
  '';
}
