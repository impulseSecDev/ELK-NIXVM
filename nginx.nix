{ config, pkgs, ... }:

{
  sops.secrets = {
    "cloudflare_api_token" = {};
    "acme_email" = {};
  };

  sops.templates."acme.env" = {
    content = ''
      CLOUDFLARE_DNS_API_TOKEN=${config.sops.placeholder."cloudflare_api_token"}
      LEGO_EMAIL=${config.sops.placeholder."acme_email"}
    '';
    path = "/run/secrets/acme.env";
    mode = "0440";
    owner = "acme";
    group = "acme";
  };

  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "placeholder@mesh.com";
      environmentFile = config.sops.templates."acme.env".path;
    };
    certs = {
      # Name the cert bundle for the root or a specific service
      "mesh.loranjennings.com" = {
        # This issues a wildcard that covers *.mesh...
        domain = "*.mesh.loranjennings.com"; 
        dnsProvider = "cloudflare";
        credentialsFile = "/var/lib/acme/secrets.env";
        group = "nginx";
      };
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts."elkbox.mesh.loranjennings.com" = {
      # Must match the string key in security.acme.certs above
      useACMEHost = "mesh.loranjennings.com";
      forceSSL = true;
      
      listen = [ { addr = "100.64.0.3"; port = 443; ssl = true; } ];
      
      locations."/" = {
        proxyPass = "http://127.0.0.1:5601";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
        '';
      };
    };
  };

  # Open the port specifically on the Tailscale interface
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 443 ];
}

