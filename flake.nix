{
  description = "AB Download Manager - Nix Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        ab-download-manager = pkgs.callPackage ./package.nix { };
      in
      {
        packages = {
          default = ab-download-manager;
          ab-download-manager = ab-download-manager;
        };

        apps.default = {
          type = "app";
          program = "${ab-download-manager}/bin/ab-download-manager";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            jdk21
            gradle
          ];
        };
      }) // {
      homeManagerModules.default = import ./module.nix;
      homeManagerModules.ab-download-manager = import ./module.nix;
    };
}
