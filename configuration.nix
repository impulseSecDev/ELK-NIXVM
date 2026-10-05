###############################################################################
# Configuration.nix
###############################################################################

{ config, lib, pkgs, ... }:

{
  imports =
    [ 
      ./disko-config.nix
      ./prochot.nix
      ./elk.nix
      ./fluent-bit.nix
      ./wireguard.nix
      ./wazuh-agent.nix
      ./nginx.nix
      ./fail2ban.nix
      ./suricata.nix
    ];

  # swapDevices = [{
  #   device = "/var/lib/swapfile";
  #   size = 4 * 1024;
  # }];

  sops.secrets."user_password" = {
    neededForUsers = true;
  };

  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    age.keyFile = "/var/lib/sops-nix/keys.txt";
  };
  boot.kernelPackages = pkgs.linuxPackages; 
  boot.supportedFilesystems = lib.mkForce [ "vfat" "fat32" "exfat" "ext4" "btrfs" ];

  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
    autoGenerateKeys.enable = true;
    autoEnrollKeys = {
      enable = true;
      # Automatically reboot to enroll the keys in the firmware
      autoReboot = true;
    };
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  networking.hostName = "ELKbox"; # Define your hostname.

  # Configure network connections interactively with nmcli or nmtui.
  networking.networkmanager.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.tim = {
    isNormalUser = true;
    hashedPasswordFile = config.sops.secrets."user_password".path;
    extraGroups = [ "wheel" "docker" ]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [
      btop
      sops
      tmux
    ];
   };

   nix.settings.trusted-users = [ "root" "tim" ];

   nixpkgs.config.allowUnfree = true;

   users.users.root.hashedPassword = "!";

   programs.neovim.enable = true;

  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    suricata
  ];

  services.openssh = {
    enable = false;
    ports = [ 22 ];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  services.tailscale = {
    enable = true;
  };

  virtualisation.docker = {
    enable = true;
  };


  environment = {
    shellAliases = {
      sops-edit = "/var/lib/sops-nix/keys.txt";
    };
    variables = {
      EDITOR = "nvim";
      SUDO_EDITOR = "nvim";
      VISUAL = "nvim";
      SOPS_EDITOR = "vim";
    };
  };
  system.stateVersion = "26.05"; 
}
