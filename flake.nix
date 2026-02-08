{
  description = "fm-ruff - Flymake backend for python using ruff";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-emacs29.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  outputs = { self, nixpkgs, nixpkgs-emacs29 }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          pkgs-emacs29 = import nixpkgs-emacs29 {
            inherit system;
            config.permittedInsecurePackages = [ "emacs-nox-29.4" ];
          };
        in
        {
          default = pkgs.mkShell {
            buildInputs = [
              pkgs.emacs
              pkgs.emacs.pkgs.cask
              pkgs.just
              pkgs.ruff
            ];
          };
          emacs29 = pkgs.mkShell {
            buildInputs = [
              pkgs-emacs29.emacs29-nox
              pkgs-emacs29.emacs29-nox.pkgs.cask
              pkgs.just
              pkgs.ruff
            ];
          };
        });
    };
}
