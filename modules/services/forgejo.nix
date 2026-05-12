{ config, ... }:
{
  services.forgejo = {
    enable = true;
    stateDir = "/var/lib/forgejo";
    database.type = "sqlite3";

    settings = {
      server = {
        # 127.0.0.1 + trustedInterfaces tailscale0 = tailnet-only access
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = 3001;
        DOMAIN = "git.${config.my.domain}";
        ROOT_URL = "https://git.${config.my.domain}/";
      };

      # personal instance = no public signups
      service.DISABLE_REGISTRATION = true;

      repository.DEFAULT_BRANCH = "main";

      session.COOKIE_SECURE = true;
    };
  };
}
