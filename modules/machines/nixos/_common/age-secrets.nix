{ config, lib, ... }:
{
  # Every agenix secret file exists at the pinned revision of its source
  assertions = lib.mapAttrsToList (name: secret: {
    assertion = builtins.pathExists secret.file;
    message = "age.secrets.${name}.file does not exist: ${toString secret.file}";
  }) config.age.secrets;
}
