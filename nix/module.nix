# Production server config
{ self }:
{ config, lib, pkgs, ... }:
let
  cfg = config.services.telegram-dogbot;
  rails = "${cfg.package}/bin/rails";

  # Env shared by server and data-purge services
  sharedEnvironment = {
    HOME = cfg.dataDir;
    RAILS_ENV = "production";
    BOOTSNAP_CACHE_DIR = "${cfg.dataDir}/cache";
    WEB_CONCURRENCY = toString cfg.pumaMaxWorkers;
    RAILS_MAX_THREADS = toString cfg.pumaMaxThreadsPerWorker;
    PIDFILE = "${cfg.dataDir}/telegram-dogbot.pid";
  };

  sharedServiceConfig = {
    EnvironmentFile = cfg.railsEnvFile;
    WorkingDirectory = "${cfg.package}";

    User = cfg.user;
    Group = cfg.group;

    # Hardening
    NoNewPrivileges = true;
    PrivateDevices = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectKernelLogs = true;
    ProtectControlGroups = true;
    LockPersonality = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    SystemCallArchitectures = "native";
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    BindPaths = [ "/run/postgresql" ];
    ReadWritePaths = [ cfg.dataDir ];
  };
in
{
  options.services.telegram-dogbot = {
    enable = lib.mkEnableOption "Enable DogBot (Telegram bot, webhook mode)";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3001;
      description = "Port for the webhook server (put a TLS-terminating reverse proxy in front of it)";
    };
    bindAddr = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "The address to bind to";
    };
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/telegram-dogbot";
      description = "Data directory (PIDs, bootsnap cache)";
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = "dogbot";
      description = "System user to run as (also used as the postgres role, via peer auth)";
    };
    group = lib.mkOption {
      type = lib.types.str;
      default = "dogbot";
    };
    railsEnvFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to INI file containing RAILS_MASTER_KEY=12345... (contents of config/credentials/production.key)";
    };
    package = lib.mkOption {
      type = lib.types.package;
      description = "The rails application package";
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
    };

    # https://github.com/puma/puma?tab=readme-ov-file#thread-pool
    # https://github.com/puma/puma/blob/main/docs/deployment.md
    pumaMaxWorkers = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = "WEB_CONCURRENCY - max number of puma worker processes";
    };
    pumaMaxThreadsPerWorker = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = "RAILS_MAX_THREADS - max threads per worker (also the DB pool size)";
    };

    dataPurgeSchedule = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "When to run `rails nightly_data_purge` (systemd.time OnCalendar format)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Prod dataDir setup
    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0750 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.dataDir}/cache' 0750 ${cfg.user} ${cfg.group} - -"
    ];

    # Prod rails server (receives telegram webhooks)
    systemd.services.telegram-dogbot = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "postgresql.service" ];
      wants = [ "network-online.target" ];
      requires = [ "postgresql.service" ];

      environment = sharedEnvironment;

      serviceConfig = sharedServiceConfig // {
        ExecStartPre = "${rails} db:prepare";
        ExecStart = "${rails} server --binding ${cfg.bindAddr} --port ${toString cfg.port}";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    # Deletes old messages & other data from the DB
    systemd.services.telegram-dogbot-data-purge = {
      after = [ "postgresql.service" "telegram-dogbot.service" ];
      requires = [ "postgresql.service" ];

      environment = sharedEnvironment;

      serviceConfig = sharedServiceConfig // {
        Type = "oneshot";
        ExecStart = "${rails} nightly_data_purge";
      };
    };
    systemd.timers.telegram-dogbot-data-purge = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.dataPurgeSchedule;
        Persistent = true;
      };
    };

    # Prod database - explore with `sudo -u postgres -- psql`
    services.postgresql = {
      enable = true;
      ensureUsers = [
        {
          name = cfg.user;
          ensureClauses = { createdb = true; };
        }
      ];
    };

    users.users = lib.mkIf (cfg.user == "dogbot") {
      dogbot = {
        group = cfg.group;
        isSystemUser = true;
      };
    };
    users.groups = lib.mkIf (cfg.group == "dogbot") {
      dogbot = { };
    };
  };
}
