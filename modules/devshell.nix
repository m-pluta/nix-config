{ inputs, ... }:
{
  systems = [
    "aarch64-darwin"
    "x86_64-linux"
  ];
  imports = [ inputs.treefmt-nix.flakeModule ];
  perSystem =
    { pkgs, inputs', ... }:
    let
      # Lets bash-completion find the just completion through XDG_DATA_DIRS in the dev shell.
      justCompletion = pkgs.runCommand "just-completion" { } ''
        install -Dm644 ${../bin/just-completion.bash} $out/share/bash-completion/completions/just
      '';
    in
    {
      treefmt = {
        projectRootFile = "flake.nix";
        settings.global.excludes = [
          "*.lock"
          ".gitignore"
        ];
        programs.nixfmt.enable = true;
        programs.nixfmt.package = pkgs.nixfmt-rfc-style;
        programs.deadnix.enable = true;
        programs.shellcheck.enable = true;
      };
      packages.default = pkgs.mkShell {
        packages = [
          pkgs.jq
          # Unstable for the dynamic completion that the host completion builds on.
          inputs'.nixpkgs-unstable.legacyPackages.just
          pkgs.nh
          pkgs.mosh
          pkgs.nixos-rebuild-ng
        ];
        shellHook = ''
          export XDG_DATA_DIRS="${justCompletion}/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
        '';
      };
    };
}
