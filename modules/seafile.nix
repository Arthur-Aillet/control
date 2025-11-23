{
  config,
  helpers,
  lib,
  ...
}:

with lib;
let
  cfg = config.control.seafile;
in
{
  options.control.seafile =
    (helpers.webServiceDefaults {
      name = "Seafile";
      version = "13.0";
      subdomain = "seafile";
      port = 10011;
    })
    // {
      dbRootPassword = mkOption {
        type = types.str;
        description = ''
          MariaDB root password for Seafile.
        '';
      };

      admin = {
        email = mkOption {
          type = types.str;
          description = ''
            Init admin email for Seafile.
          '';
        };

        password = mkOption {
          type = types.str;
          description = ''
            Init admin password for Seafile.
          '';
        };
      };

      timezone = mkOption {
        type = types.str;
        default = config.time.timeZone;
        defaultText = "Your system timezone";
        description = ''
          Set the appropriate timezone for your location from
          https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
          Defaults to your system configuration (config.time.timeZone).
        '';
      };

      paths = {
        default = helpers.mkInheritedPathOption {
          parentName = "home server global default path";
          parent = config.control.defaultPath;
          defaultSubpath = "seafile";
          description = "Default path for Seafile data";
        };

        database = helpers.mkInheritedPathOption {
          parentName = "paths.default";
          parent = cfg.paths.default;
          defaultSubpath = "database";
          description = "Path for Seafile database.";
        };

        data = helpers.mkInheritedPathOption {
          parentName = "paths.default";
          parent = cfg.paths.default;
          defaultSubpath = "data";
          description = "Path for Seafile data (uploads, etc.).";
        };
      };
    };

  config = mkIf cfg.enable {
    virtualisation.docker.enable = true;
    virtualisation.oci-containers.backend = "docker";

    virtualisation.oci-containers.containers = {
      seafile-db = {
        image = "mariadb:10.11";
        environment = {
          MYSQL_ROOT_PASSWORD = cfg.dbRootPassword;
          MYSQL_LOG_CONSOLE = "false";
        };
        volumes = [
          "${cfg.paths.database}:/var/lib/mysql"
        ];
        extraOptions = [
          "--network=seafile-net"
          "--pull=always"
        ];
      };

      seafile-memcached = {
        image = "memcached:1.6";
        extraOptions = [
          "--network=seafile-net"
          "--pull=always"
          "--entrypoint=memcached -m 256"
        ];
      };

      seafile = {
        image = "seafileltd/seafile-mc:${cfg.version}";
        ports = helpers.webServicePort config cfg 80;
        environment = {
          DB_HOST = "seafile-db";
          DB_ROOT_PASSWD = cfg.dbRootPassword;
          INIT_SEAFILE_ADMIN_EMAIL = cfg.admin.email;
          INIT_SEAFILE_ADMIN_PASSWORD = cfg.admin.password;
          TIME_ZONE = cfg.timeeone;
          SEAFILE_SERVER_PROTOCOL = "https";
          SEAFILE_SERVER_HOSTNAME =
            if config.control.routing.enable then
              "${cfg.subdomain}.${config.control.routing.domain}"
            else
              "localhost";
        };
        volumes = [
          "${cfg.paths.data}:/shared"
        ];
        extraOptions = [
          "--network=seafile-net"
          "--pull=always"
        ];
      };
    };

    systemd.services = helpers.mkDockerNetworkService {
      networkName = "seafile-net";
      dockerCli = "${config.virtualisation.docker.package}/bin/docker";
    };
  };
}
