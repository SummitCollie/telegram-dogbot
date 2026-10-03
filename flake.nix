{
  description = "telegram-dogbot";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Ruby/bundler
    ruby-nix.url = "github:inscapist/ruby-nix";
    ruby-nix.inputs.nixpkgs.follows = "nixpkgs";

    bundix.url = "github:inscapist/bundix/main";
    bundix.inputs.nixpkgs.follows = "nixpkgs";

    # Ruby versions
    bob-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
    bob-ruby.inputs.nixpkgs.follows = "nixpkgs";

    # Development environment
    process-compose.url = "github:Platonic-Systems/process-compose-flake";
    services-flake.url = "github:juspay/services-flake";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f rec {
        pkgs =
          (import nixpkgs {
            inherit system;
            overlays = [ inputs.bob-ruby.overlays.default ];
          });

        railsApp = import ./nix/package.nix {
          inherit pkgs inputs system;
        };

        devShell = import ./nix/shell.nix {
          inherit pkgs inputs railsApp;
        };
      });
    in
    {
      packages = forAllSystems ({ railsApp, devShell, ... }: {
        default = railsApp;
        devenv = devShell.passthru.devenv;
      });

      devShells = forAllSystems ({ devShell, ... }: {
        default = devShell;
      });

      nixosModules.default = import ./nix/module.nix { inherit self; };
    };
}
