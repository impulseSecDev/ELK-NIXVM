# Fluent-bit — ELK VM Module
###############################################################################
{ config, lib, pkgs, ... }:
{
  sops.secrets = {
    "elastic_password" = {};
    "elastic_user" = {};
  };

  # Open the port for OPNsense log traffic
  networking.firewall.allowedTCPPorts = [ 5140 ];

  # Lua script for OPNsense filterlog parsing
  environment.etc."fluent-bit/opnsense-filterlog-parse.lua".text = ''
    function parse_filterlog(tag, timestamp, record)
      local msg = record["message"] or ""

      -- Only process filterlog messages (CSV format starting with rule number)
      if not string.match(msg, "^%d+,") then
        return 0, timestamp, record
      end

      -- Split CSV into fields
      local fields = {}
      for field in string.gmatch(msg .. ",", "([^,]*),") do
        table.insert(fields, field)
      end

      -- Common fields (positions 1-9 are always the same)
      record["rule_num"]   = fields[1]
      record["sub_rule"]   = fields[2]
      record["anchor"]     = fields[3]
      record["tracker"]    = fields[4]
      record["interface"]  = fields[5]
      record["reason"]     = fields[6]
      record["action"]     = fields[7]
      record["direction"]  = fields[8]
      record["ip_version"] = fields[9]

      local offset = 9

      if fields[9] == "4" then
        record["ip_tos"]       = fields[offset + 1]
        record["ip_ecn"]       = fields[offset + 2]
        record["ip_ttl"]       = fields[offset + 3]
        record["ip_id"]        = fields[offset + 4]
        record["ip_offset"]    = fields[offset + 5]
        record["ip_flags"]     = fields[offset + 6]
        record["ip_proto_id"]  = fields[offset + 7]
        record["protocol"]     = fields[offset + 8]
        record["ip_length"]    = fields[offset + 9]
        record["src_ip"]       = fields[offset + 10]
        record["dst_ip"]       = fields[offset + 11]
        offset = offset + 11

      elseif fields[9] == "6" then
        record["ip_class"]     = fields[offset + 1]
        record["ip_flow"]      = fields[offset + 2]
        record["ip_hop_limit"] = fields[offset + 3]
        record["protocol"]     = fields[offset + 4]
        record["ip_proto_id"]  = fields[offset + 5]
        record["ip_length"]    = fields[offset + 6]
        record["src_ip"]       = fields[offset + 7]
        record["dst_ip"]       = fields[offset + 8]
        offset = offset + 8
      else
        return 1, timestamp, record
      end

      local proto = (record["protocol"] or ""):lower()

      if proto == "tcp" then
        record["src_port"]    = fields[offset + 1]
        record["dst_port"]    = fields[offset + 2]
        record["data_length"] = fields[offset + 3]
        record["tcp_flags"]   = fields[offset + 4]
        record["tcp_seq"]     = fields[offset + 5]
        record["tcp_ack"]     = fields[offset + 6]
        record["tcp_window"]  = fields[offset + 7]
        record["tcp_urg"]     = fields[offset + 8]
        record["tcp_options"] = fields[offset + 9]

      elseif proto == "udp" then
        record["src_port"]    = fields[offset + 1]
        record["dst_port"]    = fields[offset + 2]
        record["data_length"] = fields[offset + 3]

      elseif proto == "icmp" then
        record["icmp_type"]   = fields[offset + 1]
        record["icmp_code"]   = fields[offset + 2]
        record["data_length"] = fields[offset + 3]

      elseif proto == "ipv6-icmp" or proto == "icmpv6" then
        record["icmp_type"]   = fields[offset + 1]
        record["data_length"] = fields[offset + 2]
      end

      record["event_type"] = "firewall"

      return 1, timestamp, record
    end
  '';

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
          name           syslog
          mode           tcp
          listen         0.0.0.0
          port           5140
          tag            opnsense-syslog
          parser         syslog-rfc5424
          buffer_chunk_size 32k
          buffer_max_size   64k

      [INPUT]
          name tail
          path /var/log/*.log
          tag  nixos.tail
          mem_buf_limit 10MB

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

      [FILTER]
          name   modify
          match  *
          remove SYSLOG_TIMESTAMP

      [FILTER]
          name    modify
          match   opnsense-syslog
          add     es_index  opnsense

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
          Record   source   vm-elkbox

      [FILTER]
          name   lua
          match  opnsense-syslog
          script /etc/fluent-bit/opnsense-filterlog-parse.lua
          call   parse_filterlog

      [OUTPUT]
          name               es
          match              *
          host               127.0.0.1
          port               9200
          http_user          ${config.sops.placeholder."elastic_user"}
          http_passwd        ${config.sops.placeholder."elastic_password"}
          logstash_format    On
          logstash_prefix_key es_index
          logstash_prefix    elkvm
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
      SupplementaryGroups = [ "adm" "suricata" ];
      StateDirectory      = lib.mkForce "fluent-bit";
      StateDirectoryMode  = "0750";
    };
  };
}
