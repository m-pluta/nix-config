{ config, ... }:
{
  services.forgejo = {
    enable = true;
    stateDir = "/var/lib/forgejo";
    database.type = "sqlite3";

    settings = {
      server = {
        # 0.0.0.0 + trustedInterfaces tailscale0 = tailnet-only access
        # switch HTTP_ADDR to 127.0.0.1 once caddy reverse-proxies it
        HTTP_ADDR = "0.0.0.0";
        HTTP_PORT = 3001;
        DOMAIN = "mikelab";
        ROOT_URL = "http://mikelab:3001/";
        # Can use once caddy is configured
        # DOMAIN = "git.${config.my.domain}";
        # ROOT_URL = "https://git.${config.my.domain}/";
      };

      # personal instance = no public signups
      service.DISABLE_REGISTRATION = true;

      repository.DEFAULT_BRANCH = "main";

      # session cookie restricted to https connections only
      # false while accessed over http - will flip to true when caddy serves https
      session.COOKIE_SECURE = false;
    };
  };
}
