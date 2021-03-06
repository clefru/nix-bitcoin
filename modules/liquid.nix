{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.liquidd;
  pidFile = "${cfg.dataDir}/liquidd.pid";
  configFile = pkgs.writeText "liquid.conf" ''
    ${optionalString cfg.testnet "testnet=1"}
    ${optionalString (cfg.dbCache != null) "dbcache=${toString cfg.dbCache}"}
    ${optionalString (cfg.prune != null) "prune=${toString cfg.prune}"}

    # Connection options
    ${optionalString (cfg.port != null) "port=${toString cfg.port}"}
    ${optionalString (cfg.proxy != null) "proxy=${cfg.proxy}"}
    listen=${if cfg.listen then "1" else "0"}

    # RPC server options
    ${optionalString (cfg.rpc.port != null) "rpcport=${toString cfg.rpc.port}"}
    ${concatMapStringsSep  "\n"
      (rpcUser: "rpcauth=${rpcUser.name}:${rpcUser.passwordHMAC}")
      (attrValues cfg.rpc.users)
    }
    ${optionalString (cfg.rpcuser != null) "rpcuser=${cfg.rpcuser}"}
    ${optionalString (cfg.rpcpassword != null) "rpcpassword=${cfg.rpcpassword}"}

    # Extra config options (from liquidd nixos service)
    ${cfg.extraConfig}
  '';
  cmdlineOptions = concatMapStringsSep " " (arg: "'${arg}'") [
    "-datadir=${cfg.dataDir}"
    "-pid=${pidFile}"
  ];
  hexStr = types.strMatching "[0-9a-f]+";
  rpcUserOpts = { name, ... }: {
    options = {
      name = mkOption {
        type = types.str;
        example = "alice";
        description = ''
          Username for JSON-RPC connections.
        '';
      };
      passwordHMAC = mkOption {
        type = with types; uniq (strMatching "[0-9a-f]+\\$[0-9a-f]{64}");
        example = "f7efda5c189b999524f151318c0c86$d5b51b3beffbc02b724e5d095828e0bc8b2456e9ac8757ae3211a5d9b16a22ae";
        description = ''
          Password HMAC-SHA-256 for JSON-RPC connections. Must be a string of the
          format <SALT-HEX>$<HMAC-HEX>.
        '';
      };
    };
    config = {
      name = mkDefault name;
    };
  };
in {
  options = {

    services.liquidd = {
      enable = mkEnableOption "Liquid daemon";

      extraConfig = mkOption {
        type = types.lines;
        default = "";
        example = ''
          par=16
          rpcthreads=16
          logips=1

        '';
        description = "Additional configurations to be appended to <filename>liquid.conf</filename>.";
      };
      dataDir = mkOption {
        type = types.path;
        default = "/var/lib/liquidd";
        description = "The data directory for liquidd.";
      };

      user = mkOption {
        type = types.str;
        default = "liquid";
        description = "The user as which to run liquidd.";
      };
      group = mkOption {
        type = types.str;
        default = cfg.user;
        description = "The group as which to run liquidd.";
      };

      rpc = {
        port = mkOption {
          type = types.nullOr types.ints.u16;
          default = null;
          description = "Override the default port on which to listen for JSON-RPC connections.";
        };
        users = mkOption {
          default = {};
          example = {
            alice.passwordHMAC = "f7efda5c189b999524f151318c0c86$d5b51b3beffbc02b724e5d095828e0bc8b2456e9ac8757ae3211a5d9b16a22ae";
            bob.passwordHMAC = "b2dd077cb54591a2f3139e69a897ac$4e71f08d48b4347cf8eff3815c0e25ae2e9a4340474079f55705f40574f4ec99";
          };
          type = with types; loaOf (submodule rpcUserOpts);
          description = ''
            RPC user information for JSON-RPC connnections.
          '';
        };
      };

      rpcuser = mkOption {
          type = types.nullOr types.string;
          default = null;
          description = "Username for JSON-RPC connections";
      };
      rpcpassword = mkOption {
          type = types.nullOr types.string;
          default = null;
          description = "Password for JSON-RPC connections";
      };

      testnet = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to use the test chain.";
      };
      port = mkOption {
        type = types.nullOr types.ints.u16;
        default = null;
        description = "Override the default port on which to listen for connections.";
      };
      proxy = mkOption {
        type = types.nullOr types.string;
        default = null;
        description = "Connect through SOCKS5 proxy";
      };
      listen = mkOption {
        type = types.bool;
        default = false;
        description = ''
          If enabled, the liquid service will listen.
        '';
      };
      dbCache = mkOption {
        type = types.nullOr (types.ints.between 4 16384);
        default = null;
        example = 4000;
        description = "Override the default database cache size in megabytes.";
      };
      prune = mkOption {
        type = types.nullOr (types.coercedTo
          (types.enum [ "disable" "manual" ])
          (x: if x == "disable" then 0 else 1)
          types.ints.unsigned
        );
        default = null;
        example = 10000;
        description = ''
          Reduce storage requirements by enabling pruning (deleting) of old
          blocks. This allows the pruneblockchain RPC to be called to delete
          specific blocks, and enables automatic pruning of old blocks if a
          target size in MiB is provided. This mode is incompatible with -txindex
          and -rescan. Warning: Reverting this setting requires re-downloading
          the entire blockchain. ("disable" = disable pruning blocks, "manual"
          = allow manual pruning via RPC, >=550 = automatically prune block files
          to stay under the specified target size in MiB)
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.liquidd ];
    systemd.services.liquidd = {
      description = "Liquid daemon";
      requires = [ "liquid-rpcpassword-key.service" ];
      after = [ "network.target" "liquid-rpcpassword-key.service" ];
      wantedBy = [ "multi-user.target" ];
      preStart = ''
        if ! test -e ${cfg.dataDir}; then
          mkdir -m 0770 -p '${cfg.dataDir}'
          chown '${cfg.user}:${cfg.group}' '${cfg.dataDir}'
        fi
        cp '${configFile}' '${cfg.dataDir}/liquid.conf'
        chmod o-rw  '${cfg.dataDir}/liquid.conf'
        chown '${cfg.user}:${cfg.group}' '${cfg.dataDir}/liquid.conf'
        echo "rpcpassword=$(cat /secrets/liquid-rpcpassword)" >> '${cfg.dataDir}/liquid.conf'
        echo "mainchainrpcpassword=$(cat /secrets/bitcoin-rpcpassword)" >> '${cfg.dataDir}/liquid.conf'
      '';
      serviceConfig = {
        Type = "simple";
        User = "${cfg.user}";
        Group = "${cfg.group}";
        ExecStart = "${pkgs.liquidd}/bin/liquidd ${cmdlineOptions}";
        StateDirectory = "liquidd";
        PIDFile = "${pidFile}";
        Restart = "on-failure";

        # Hardening measures
        PrivateTmp = "true";
        ProtectSystem = "full";
        NoNewPrivileges = "true";
        PrivateDevices = "true";
        MemoryDenyWriteExecute = "true";

        # Permission for preStart
        PermissionsStartOnly = "true";
      };
    };
    users.users.${cfg.user} = {
      name = cfg.user;
      #uid  = config.ids.uids.liquid;
      group = cfg.group;
      extraGroups = [ "keys" ];
      description = "Liquid daemon user";
      home = cfg.dataDir;
    };
    users.groups.${cfg.group} = {
      name = cfg.group;
      #gid = config.ids.gids.liquid;
    };
  };
}
