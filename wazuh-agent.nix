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

  sops.secrets."wazuh_manager_server" = {};
  sops.secrets."wazuh_agent_name" = {};
  sops.secrets."wazuh_registration_password" = {};

  sops.templates."wazuh-agent.env" = {
    content = ''
      WAZUH_MANAGER_SERVER=${config.sops.placeholder."wazuh_manager_server"}
      WAZUH_AGENT_NAME=${config.sops.placeholder."wazuh_agent_name"}
      WAZUH_REGISTRATION_PASSWORD=${config.sops.placeholder."wazuh_registration_password"}
    '';
    path = "/run/secrets/wazuh-agent.env";
    mode = "0444";
  };

  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      wazuh-agent = {
        image = "wazuh/wazuh-agent:4.14.3";

        environmentFiles = [ config.sops.templates."wazuh-agent.env".path ];

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

