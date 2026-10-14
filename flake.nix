{
  description = "Bento: тема SDDM в стиле лока из quickshell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      nixosModules.default = import ./nix/nixos.nix;

      # Своя сборка: .override { settings = { … }; avatar = ./Fox.glb; }
      packages = forAll (pkgs: {
        default = pkgs.callPackage ./nix/theme.nix { };
      });

      formatter = forAll (pkgs: pkgs.nixfmt);
    };
}
