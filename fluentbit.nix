{ config, lib, pkgs, ... }:
{
  services.fluent-bit = {
    enable = true;
    settings = {
      service = {
        flush = 1;
        log_level = "info";
        daemon = "off";
      };
      pipeline = {
        inputs = [
          {
            name = "systemd";
            tag = "elkstack.journal";
          }
          {
            name = "tail";
            path = "/var/log/*.log";
            tag = "nixos.tail";
          }
        ];
        outputs = [
          {
            name = "es";
            match = "*";
            host = "127.0.0.1";
            port = 9200;
            http_user = "$\{ELASTIC_USERNAME}";
            http_passwd = "$\{ELASTIC_PASSWORD}";
            logstash_format = true;
            logstash_prefix = "elkvm";
            suppress_type_name = true;
          }
        ];
      };
    };
  };
  systemd.services.fluent-bit.serviceConfig = {
    EnvironmentFile = "/etc/secrets/elastic.env";
    SupplementaryGroups = [ "adm" ];
  };

  #FLUENT-BIT DATABASE DIRECTORY
  systemd.tmpfiles.rules = [
    "d /var/lib/fluent-bit 0750 fluent-bit fluent-bit -"
  ];
}
