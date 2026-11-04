{ ... }:
{
  # Root-equivalent through wheel.
  users = {
    users.deploy = {
      isNormalUser = true;
      group = "deploy";
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOuIvCbXJLcHBLIgP1NdsTrleJEHQevux9OTuI3yddCr deploy@forgejo-actions"
      ];
    };
    groups.deploy = { };
  };
}
