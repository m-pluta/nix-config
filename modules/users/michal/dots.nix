{ ... }:
{
  nixpkgs = {
    overlays = [ ];
    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
  };

  home = {
    username = "michal";
    homeDirectory = "/home/michal";
    stateVersion = "25.11";
  };

  imports = [
    ./gitconfig.nix
  ];

  programs.nix-index.enable = true;
  programs.home-manager.enable = true;
  systemd.user.startServices = "sd-switch";
}
