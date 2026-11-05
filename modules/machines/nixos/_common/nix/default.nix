{ lib, ... }:
{
  nix = {
    settings = {
      trusted-users = [
        "root"
        "@wheel"
      ];
      experimental-features = lib.mkDefault [
        "nix-command"
        "flakes"
      ];
      extra-substituters = [ "https://cache.mpluta.dev/nix-config" ];
      extra-trusted-public-keys = [ "nix-config:zGjB0uPB1ecKv9Ab4rHwQF3I83zAveDYNHvnVEihppA=" ];
      connect-timeout = 5;
      fallback = true;
    };

    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 30d";
      persistent = true;
    };
    optimise = {
      automatic = true;
      dates = [ "daily" ];
    };
  };

  nixpkgs = {
    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
  };
}
