{
  description = "BonnSnuffles NixOS";

  inputs = {
    # ---------- stable base ----------
    # Everything comes from here unless explicitly pulled from pkgs-unstable.
    # This is what keeps boot.kernelPackages on a 25.11 kernel.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    # ---------- unstable, for cherry-picks ----------
    # Exposed to configuration.nix as `pkgs-unstable`.
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # ---------- caelestia shell ----------
    # Follows unstable, not the stable base: the shell tracks recent
    # Quickshell/Qt and won't build against 25.11.
    caelestia-shell = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, caelestia-shell, ... }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;

        # Anything listed here becomes available as a function argument
        # at the top of configuration.nix.
        specialArgs = {
          inherit caelestia-shell;

          pkgs-unstable = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
        };

        modules = [ ./configuration.nix ];
      };
    };
}
