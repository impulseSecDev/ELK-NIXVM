# Fluent-bit — ELK VM Module
###############################################################################
{ config, lib, pkgs, ... }:
{
  sops.secrets = {
    "elastic_password" = {};
    "elastic_user" = {};
  };

  # Lua script for Tailscale SSH parsing
  environment.etc."fluent-bit/tailscale-parse.lua".text = ''
    function parse_tailscale(tag, timestamp, record)
      local cmdline = record["_CMDLINE"]
      if cmdline then
        local ip = string.match(cmdline, "-h%s+(100%.[%d%.]+)")
        if ip then
          record["tailscale_src_ip"] = ip
          record["tailscale_ssh"]    = true
          record["event_type"]       = "tailscale_login"
        end
      end
      return 1, timestamp, record
    end
  '';

  # Lua script for Fail2Ban parsing
  environment.etc."fluent-bit/fail2ban-parse.lua".text = ''
    function parse_fail2ban(tag, timestamp, record)
      local msg = record["message"] or ""
      local jail, action, ip = string.match(msg, "%%[([^%%]]+)%%]%s+(%%w+)%s+([%%d%%.]+)")
      if jail then
        record["jail"] = jail
        record["action"] = action
        record["src_ip"] = ip
      end
      return 1, timestamp, record
    end
  '';

  # Custom Parsers definition
  environment.etc."fluent-bit/parsers.conf".text = ''
    [PARSER]
        Name        suricata-eve
        Format      json
        Time_Key    timestamp
        Time_Format %Y-%m-%dT%H:%M:%S.%L%z
        Time_Keep   On

    [PARSER]
        Name        syslog-rfc5424
        Format      regex
        Regex       ^<(?<pri>[0-9]+)>+(?<version>[1-9]) (?<timestamp>[^ ]+) (?<hostname>[^ ]+) (?<appname>[^ ]+) (?<procid>[^ ]+) (?<msgid>[^ ]+) (?<structured_data>(\[.+\]|[^ ])) (?<message>.+)$
        Time_Key    timestamp
        # Removed .%L to match the timestamp OPNsense is actually sending
        Time_Format %Y-%m-%dT%H:%M:%S%z
        Time_Keep   On

    [PARSER]
        Name   nginx
        Format regex
        Regex ^(?<remote>[^ ]*) (?<host>[^ ]*) (?<user>[^ ]*) \[(?<time>[^\]]*)\] "(?<method>\S+)(?: +(?<path>[^\"]*?)(?: +\S*)?)?" (?<code>[^ ]*) (?<size>[^ ]*)(?: "(?<referer>[^\"]*)" "(?<agent>[^\"]*)")
        Time_Key time
        Time_Format %d/%b/%Y:%H:%M:%S %z

    [PARSER]
        Name        nginx-error
        Format      regex
        Regex       ^(?<time>\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2}) \[(?<level>\w+)\] (?<pid>\d+)#(?<tid>\d+): (?<message>.+)$
        Time_Key    time
        Time_Format %Y/%m/%d %H:%M:%S
  '';

  sops.templates."fluent-bit.conf" = {
    content = ''
      [SERVICE]
          flush     1
          log_level info
          daemon    off
          Parsers_File /etc/fluent-bit/parsers.conf
          storage.path /var/lib/fluent-bit/storage
          storage.max_chunks_up   128
          storage.backlog.mem_limit 100M

      [INPUT]
          name systemd
          tag  elkstack.journal
          mem_buf_limit 10MB
          storage.type  filesystem

      [INPUT]
          name              systemd
          tag               elkvm.fail2ban
          systemd_filter    _SYSTEMD_UNIT=fail2ban.service
          db                /var/lib/fluent-bit/fail2ban.db
          mem_buf_limit 10MB

      [INPUT]
          name              tail
          tag               elkvm.suricata.eve
          path              /var/log/suricata/eve.json
          db                /var/lib/fluent-bit/suricata-eve.db
          mem_buf_limit     10MB
          skip_long_lines   on
          refresh_interval  5
          parser            suricata-eve

      [INPUT]
          name              tail
          tag               elkvm.suricata.fast
          path              /var/log/suricata/fast.log
          db                /var/lib/fluent-bit/suricata-fast.db
          mem_buf_limit     5MB
          skip_long_lines   on
          refresh_interval  5

      [INPUT]
          name              tail
          tag               elkvm.nginx.access
          path              /var/log/nginx/access.log
          mem_buf_limit     5MB
          skip_long_lines   on
          refresh_interval  5
          Parser            nginx
          db                /var/lib/fluent-bit/nginx.db

      [INPUT]
          name              tail
          tag               elkvm.nginx.error
          path              /var/log/nginx/error.log
          mem_buf_limit     5MB
          skip_long_lines   on
          refresh_interval  5
          Parser            nginx-error
          db                /var/lib/fluent-bit/nginx-error.db
          

      [FILTER]
          name   modify
          match  *
          remove SYSLOG_TIMESTAMP

      [FILTER]
          name    modify
          match   elkvm.*
          add     es_index  elkvm

      [FILTER]
          name    lua
          match   *.journal
          script  /etc/fluent-bit/tailscale-parse.lua
          call    parse_tailscale

      [FILTER]
          name   lua
          match  elkvm.fail2ban
          script /etc/fluent-bit/fail2ban-parse.lua
          call   parse_fail2ban

      [FILTER]
          name     record_modifier
          match    elkvm.*
          Record   hostname elkbox
          Record   source   elkbox

      [OUTPUT]
          name               es
          match              *
          host               127.0.0.1
          port               9200
          http_user          ${config.sops.placeholder."elastic_user"}
          http_passwd        ${config.sops.placeholder."elastic_password"}
          logstash_format    Off
          Index              elkvm
          suppress_type_name On
          buffer_size        10MB
    '';
    path = "/run/secrets/fluent-bit.conf";
    mode = "0444";
    owner = "root";
    group = "root";
  };

  services.fluent-bit = {
    enable = true;
    configurationFile = config.sops.templates."fluent-bit.conf".path;
  };

  systemd.services.fluent-bit = {
    serviceConfig = {
      SupplementaryGroups = [ "adm" "suricata" "nginx" ];
      StateDirectory      = lib.mkForce "fluent-bit";
      StateDirectoryMode  = "0750";
    };
  };
}
