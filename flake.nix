{
  description = "COSMIC-like GNOME panel/dock/workspaces (dash-to-panel + blur + space-bar)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.default = pkgs.hello;
      }
    )
    // {
      nixosModules = {
        default = import ./modules/nixos.nix;
        gnome-cosmic-ui = import ./modules/nixos.nix;
      };

      homeManagerModules = {
        default = import ./modules/home-manager.nix;
        gnome-cosmic-ui = import ./modules/home-manager.nix;
      };
    };
}
