{ config, pkgs, ... }:

{
  sops.secrets = {
    # Ensure the acme service can actually read the decrypted file
    "cloudflare_api_token" = {
      owner = config.users.users.acme.name;
    };
    "acme_email" = {
      owner = config.users.users.acme.name;
    };
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
        credentialFiles = {
          "CLOUDFLARE_DNS_API_TOKEN_FILE" = config.sops.secrets."cloudflare_api_token".path;
        };
        group = "nginx";
      };
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts = {
      # Default Fallback for HTTP (Port 80)
      "default-http-fallback" = {
        default = true; # Catches all traffic not matched by other virtual hosts
        listen = [ { addr = "100.64.0.3"; port = 80; } ];
        extraConfig = ''
          server_name _;
          error_page 400 401 402 403 404 405 429 497 500 =444 /;
          return 444;
        '';
      };

      # Default Fallback for HTTPS (Port 443)
      "default-https-fallback" = {
        default = true; # Catches all traffic not matched by other virtual hosts
        listen = [ { addr = "100.64.0.3"; port = 443; ssl = true; } ];
        extraConfig = ''
          server_name _;
          ssl_reject_handshake on; # Reject non-SSL attempts
          error_page 400 401 402 403 404 405 429 497 500 =444 /;
          return 444;
        '';
      };

      "elkbox.mesh.loranjennings.com" = {
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
  };

  # Open the port specifically on the Tailscale interface
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 443 ];
}

