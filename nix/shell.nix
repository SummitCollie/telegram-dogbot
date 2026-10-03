{ pkgs, inputs, railsApp, ... }:
let
  servicesMod = (import inputs.process-compose.lib { inherit pkgs; }).evalModules {
    modules = [
      inputs.services-flake.processComposeModules.default
      {
        services.postgres."pg1" = {
          enable = true;
          dataDir = "./.postgres";
          port = 5434; # Must match config/database.yml
        };

        # Dev-mode bot (polls telegram's servers, no webhook needed)
        settings.processes."bot-poller" = {
          command = "./bin/rails db:prepare && exec ./bin/rails telegram:bot:poller";
          depends_on."pg1".condition = "process_healthy";
          availability.restart = "on_failure";
        };
      }
    ];
  };
in
pkgs.mkShell {
  inputsFrom = [
    railsApp
    servicesMod.config.services.outputs.devShell
  ];

  packages = with pkgs; [
    inputs.bundix.packages.${pkgs.stdenv.hostPlatform.system}.default
    postgresql_18

    # Protect the process-compose environment from Nix GC
    servicesMod.config.outputs.package
  ];

  shellHook = ''
    export PATH="$PATH:$PWD/bin"

    echo ""
    echo "Use \`nix run .#devenv\` to start postgres & the bot (poll mode)"
    echo ""
  '';

  # Expose the process-compose package so the flake can output it
  passthru.devenv = servicesMod.config.outputs.package;
}
