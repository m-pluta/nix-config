{
  lib,
  config,
  ...
}:
let
  service = "plausible";
  serviceLib = import ../lib.nix { inherit lib; };
  cfg = config.homelab.services.${service};
  hl = config.homelab;
in
{
  options.homelab.services.${service} =
    serviceLib.mkServiceOptions {
      port = 8000;
      url = "numbers.${hl.baseDomain}";
      homepage = {
        name = "Plausible";
        description = "Open-source web analytics platform";
        icon = "plausible.svg";
        category = "Observability";
      };
    }
    // {
      secretKeybaseFile = lib.mkOption {
        type = lib.types.str;
        example = lib.literalExpression ''
          pkgs.writeText "keybase.txt" '''
            foobar
          '''
        '';
      };
    };
  config = lib.mkIf cfg.enable {
    services.plausible = {
      enable = true;
      server = {
        port = cfg.port;
        baseUrl = "https://${cfg.url}";
        secretKeybaseFile = cfg.secretKeybaseFile;
      };
    };
    homelab.ingress.routes."${cfg.url}".port = cfg.port;
  };
}
