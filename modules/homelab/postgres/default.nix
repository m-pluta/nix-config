{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.homelab.postgres;
in
{
  options.homelab.postgres = {
    enable = lib.mkEnableOption "the PostgreSQL server shared by this host's services";
    version = lib.mkOption {
      type = lib.types.ints.positive;
      description = "PostgreSQL major version. Changing it needs a manual data migration.";
      example = 17;
    };
  };

  config = {
    assertions = [
      {
        assertion = config.services.postgresql.enable -> cfg.enable;
        message = "homelab.postgres: a service on ${config.networking.hostName} enables PostgreSQL, set homelab.postgres.enable";
      }
    ];

    services.postgresql = lib.mkIf cfg.enable {
      enable = true;
      package = pkgs."postgresql_${toString cfg.version}";
    };
  };
}
