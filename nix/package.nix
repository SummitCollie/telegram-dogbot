{ pkgs, inputs, system, ... }:
let
  # Pull ruby version from dotfile
  ruby = (inputs.bob-ruby.lib.packageFromRubyVersionFile {
    inherit system;
    file = ../.ruby-version;
  }).override {
    docSupport = true;
    parallelBuild = false; # Required by docSupport for ruby < 3.4
  };

  gemset = import ../gemset.nix;

  # If you want to override gem build config, see
  # https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/ruby-modules/gem-config/default.nix
  gemConfig = { };

  # Manage bundler dependencies through nix
  # init gemset.nix with: `nix run github:inscapist/bundix/main -- -l`
  rubyNix = inputs.ruby-nix.lib pkgs;
  railsEnv = rubyNix {
    inherit gemset ruby;
    name = "telegram-dogbot";
    gemConfig = pkgs.defaultGemConfig // gemConfig;
  };
in
pkgs.stdenv.mkDerivation {
  name = "telegram-dogbot";
  src = ../.;

  buildInputs = [ railsEnv.env ruby ];
  buildPhase = ''
    export RAILS_ENV=production
  '';

  installPhase = ''
    mkdir -p $out

    # Rails boot process wants these to exist
    mkdir -p $out/tmp/{cache,pids,sockets}

    cp -r . $out
  '';

  # Pass through the env/ruby so the shell can inherit them easily
  passthru = {
    inherit (railsEnv) env;
    inherit ruby;
  };
}
