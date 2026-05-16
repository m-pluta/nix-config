{ config, ... }:
{
  age.secrets = {
    jellyfin-api-key.file = ../../secrets/services/jellyfin/api-key.age;
    jellyfin-admin-password.file = ../../secrets/services/jellyfin/admin-password.age;
    sonarr-api-key.file = ../../secrets/services/sonarr/api-key.age;
    sonarr-password.file = ../../secrets/services/sonarr/password.age;
    radarr-api-key.file = ../../secrets/services/radarr/api-key.age;
    radarr-password.file = ../../secrets/services/radarr/password.age;
    prowlarr-api-key.file = ../../secrets/services/prowlarr/api-key.age;
    prowlarr-password.file = ../../secrets/services/prowlarr/password.age;
  };

  nixflix = {
    enable = true;
    mediaDir = "/tank/media";
    stateDir = "/var/lib";
    mediaUsers = [ "michal" ];

    jellyfin = {
      enable = true;
      apiKey._secret = config.age.secrets.jellyfin-api-key.path;

      users.admin = {
        mutable = true;
        policy.isAdministrator = true;
        password._secret = config.age.secrets.jellyfin-admin-password.path;
      };
    };

    sonarr = {
      enable = true;
      config = {
        apiKey._secret = config.age.secrets.sonarr-api-key.path;
        hostConfig.password._secret = config.age.secrets.sonarr-password.path;
      };
    };

    radarr = {
      enable = true;
      config = {
        apiKey._secret = config.age.secrets.radarr-api-key.path;
        hostConfig.password._secret = config.age.secrets.radarr-password.path;
      };
    };

    prowlarr = {
      enable = true;
      config = {
        apiKey._secret = config.age.secrets.prowlarr-api-key.path;
        hostConfig.password._secret = config.age.secrets.prowlarr-password.path;
      };
    };
  };

  services.flaresolverr = {
    enable = true;
    port = 8191;
  };
}
