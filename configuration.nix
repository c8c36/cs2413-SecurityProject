{ pkgs, lib, ... }: {
  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = toString [
      "--disable=traefik"
      "--disable=servicelb"
    ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
    };
  };

  networking.hostName = "k3s-token-lab";
  networking.networkmanager.enable = true;

  users.users.lab = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "k3s"
    ];
    initialPassword = "lab";
  };

  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    vim
    nano
    git
    jq
    kubectl
  ];

  networking.firewall.allowedTCPPorts = [
    22
    6443 # k3s: required so that pods can reach the API server (running on port 6443 by default)
  ];

  virtualisation.virtualbox.guest.enable = true;

  image.modules.virtualbox = {
    image.fileName = lib.mkForce "k3s-token-lab.ova";
  };

  system.stateVersion = "26.05";
}
