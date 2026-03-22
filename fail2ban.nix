{ confing, lib, pkgs, ... }:
{

  services.fail2ban = {
    enable = true;
    maxretry = 5;
    bantime = "1d";
    bantime-increment = {
      enable = true;
      formula = "ban.Time * 1.5";
      maxtime = "1w";
      overalljails = true;
    };
    jails = {
      sshd = {
        enabled = true;
        settings = {
          journalmatch = "_SYSTEMD_UNIT=sshd.service";
          bantime = "2d";
          findtime = 600;
          maxretry = 3;
        };
      };
      kibana = {
        enabled = true;
        settings = {
          port = "http,https";
          filter = "kibana";
          logpath = "/var/log/nginx/access.log";
	  backend = "auto";
          maxretry = 3;
          findtime = 600;
          bantime = "1d";
        };
      };
    };
  };

  environment.etc = {
    "fail2ban/filter.d/kibana.conf".text = ''
      [Definition]
      failregex = ^<HOST> - - \[.*\] "POST /identity/connect/token HTTP/\d\.\d" 4\d\d
      ignoreregex =
    '';
  };
}
