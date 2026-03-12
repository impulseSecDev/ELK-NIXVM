# ============================================================
# wireguard.nix — WireGuard Module for ELK VM (NixOS)
# ============================================================

{ config, lib, pkgs, ... }:

{
  # Make wireguard-tools available for debugging
  environment.systemPackages = [ pkgs.wireguard-tools ];

  sops.secrets = {
    "headscale_hostname" = {};
    "wg0_private_key" = {};
    "wg0_headscale_allowedips" = {};
    "wg0_wazuh_allowedips" = {};
    "wg0_dailydriver_allowedips" = {};
    "wg0_vwvm_allowedips" = {};
    "wg0_laptop_allowedips" = {};
  };
  sops.templates."wg0.conf" = {
    content = ''
      [Interface]
      PrivateKey = ${config.sops.placeholder."wg0_private_key"}
      Address = 10.10.10.2/24
      ListenPort = 62091

      [Peer]
      # Headscale
      PublicKey = Owp1/h9AbTuRAGGGA9L0McoGbn54vWtYGRserVfrrxs=
      AllowedIPs = ${config.sops.placeholder."wg0_headscale_allowedips"}
      Endpoint = ${config.sops.placeholder."headscale_hostname"}
      PersistentKeepalive = 25

      [Peer]
      # Wazuh VM
      PublicKey = na1tRGq7v+sZyAwPMJrYzI2MFq7z4Y8EKhWaMaB5ZB4=
      AllowedIPs = ${config.sops.placeholder."wg0_wazuh_allowedips"}

      [Peer]
      # Daily Driver
      PublicKey = 51ZOUM8ant3W4DsQYkFhf642TSoH/Ct/kzTjW06p+X4=
      AllowedIPs = ${config.sops.placeholder."wg0_dailydriver_allowedips"}

      [Peer]
      # VW VM
      PublicKey = 8hppDFIJhfCzdjbNI7xqn98JxM0Bes/ZTbsZkekPEEw=
      AllowedIPs = ${config.sops.placeholder."wg0_vwvm_allowedips"}

      [Peer]
      # Laptop
      PublicKey = P+vWLcVRat/dq01yYksYeAvXtJgxo8j7C4GV05GV+0s=
      AllowedIPs = ${config.sops.placeholder."wg0_laptop_allowedips"}
      PersistentKeepalive = 25
    '';
    path = "/run/secrets/wg0.conf";
    mode = "0400";
  };

  networking.wg-quick.interfaces = {
    wg0.configFile = config.sops.templates."wg0.conf".path;
  };

  networking.firewall = {
    checkReversePath = "loose";
    interfaces = {
      "wg0" = {
        allowedTCPPorts = [ 9200 ];
      };	
      "enp1s0" = {
        allowedUDPPorts = [ 62091 ];
      };
    };  
  };
}

