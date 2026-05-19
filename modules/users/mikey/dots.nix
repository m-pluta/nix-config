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
    username = "mikey";
    homeDirectory = "/home/mikey";
    stateVersion = "25.11";
  };

  imports = [
    ./gitconfig.nix
  ];

  programs.nix-index.enable = true;
  programs.home-manager.enable = true;
  systemd.user.startServices = "sd-switch";
}
