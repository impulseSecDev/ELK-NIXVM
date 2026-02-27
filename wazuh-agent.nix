# ============================================================
# wazuh-agent.nix — Wazuh Agent Module for NixOS Hosts
# ============================================================
#
#   The agent monitors this host and ships security events,
#   FIM alerts, and log analysis results to the manager
#   which forwards them to Elasticsearch.
# ============================================================

{ config, lib, pkgs, ... }:

{
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      wazuh-agent = {
        image = "wazuh/wazuh-agent:4.14.3";

        environmentFiles = [ /etc/secrets/wazuh-agent.env ];

        extraOptions = [
          "--network=host"
          "--cap-add=SYS_PTRACE"
          "--cap-add=SYS_ADMIN"
          "--cap-add=NET_ADMIN"
        ];
      };
    };
  };
}

