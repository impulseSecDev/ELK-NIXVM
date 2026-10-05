{ pkgs, ... }:

{
  # 1. Enable the MSR kernel module so the OS can write to CPU registers
  boot.kernelModules = [ "msr" ];

  # 2. Add msr-tools to system packages for manual testing if needed
  environment.systemPackages = [ pkgs.msr-tools ];

  # 3. Create a declarative systemd service to disable BD PROCHOT at boot
  systemd.services.disable-bd-prochot = {
    description = "Disable BD PROCHOT CPU Throttling at Boot";
    after = [ "multi-user.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      # -a applies the register write to all CPU cores/threads
      ExecStart = "${pkgs.msr-tools}/bin/wrmsr -a 0x1FC 0x4004d";
      RemainAfterExit = true;
    };
  };

  # 4. Handle waking up from sleep/suspend (Dell machines usually re-lock it)
  systemd.services.disable-bd-prochot-resume = {
    description = "Disable BD PROCHOT CPU Throttling on Resume";
    after = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" "suspend-then-hibernate.target" ];
    wantedBy = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" "suspend-then-hibernate.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.msr-tools}/bin/wrmsr -a 0x1FC 0x4004d";
    };
  };
}

