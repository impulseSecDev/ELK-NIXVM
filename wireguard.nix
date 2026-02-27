# ============================================================
# wireguard.nix — WireGuard Module for ELK VM (NixOS)
# ============================================================
# SETUP — run these commands on the ELK VM before applying:

#   nix-shell -p wireguard-tools
#   with sudo sh -c ""
#   umask 077 && wg genkey > /etc/secrets/wg-elk-private
#   wg pubkey < /etc/secrets/wg-elk-private > /etc/secrets/wg-elk-public
#   cat /etc/secrets/wg-elk-public


# ============================================================

{ config, lib, pkgs, ... }:

{
  # Make wireguard-tools available for debugging
  environment.systemPackages = [ pkgs.wireguard-tools ];

  networking.wg-quick.interfaces = {
    wg0 = {
      # This machine's IP on the WireGuard tunnel subnet.
      address = [ "10.10.10.2/24" ];

      # Private key file path — generated during setup above.
      privateKeyFile = "/etc/secrets/wg-elk-private";

      peers = [
        {
          # Replace with the actual value from your VPS setup.
          publicKey = "Owp1/h9AbTuRAGGGA9L0McoGbn54vWtYGRserVfrrxs=";

          # Only route the tunnel subnet through this interface.
          # This is important — we do NOT want all ELK VM traffic
          # routed through the VPS, only Elasticsearch log traffic.
          allowedIPs = [ "10.10.10.0/24" ];

          # The VPS public IP and WireGuard port.
          endpoint = lib.strings.trim (builtins.readFile /etc/secrets/wg-endpoint);

          # Sends a keepalive packet every 25 seconds.
          persistentKeepalive = 25;
        }
      ];
    };
  };

  networking.firewall = {
    checkReversePath = "loose";
  };
}

