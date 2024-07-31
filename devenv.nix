{ inputs, pkgs, ... }:
let
  nixpkgs-unstable = import inputs.nixpkgs-unstable { system = pkgs.stdenv.system; };
in
{
  languages.ruby = {
    enable = true;
    version = "3.3.4";
    bundler.enable = false;
  };

  packages = with nixpkgs-unstable; [
    curl
    heroku
    libyaml
    openssl
  ];

  services.postgres = {
    enable = true;
    package = nixpkgs-unstable.postgresql_16;
    listen_addresses = "127.0.0.1";
    createDatabase = false;
    initialScript = ''
      CREATE ROLE postgres WITH LOGIN SUPERUSER;
    '';
  };

  # Add project bin folder to path:
  enterShell = ''
    export PATH="$DEVENV_ROOT/bin:$PATH";
  '';

  cachix.enable = false;
}
