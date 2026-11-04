{ pkgs, lib, ... }: {

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
    };
  };
  services.firewalld.enable = true;

  networking.hostName = "k3s-token-lab";
  networking.networkmanager.enable = true;

  users.users.lab = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
    ];
    initialPassword = "lab";
  };

  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    vim
    nano
    git
    jq
  ];

  virtualisation.virtualbox.guest.enable = true;

  image.modules.virtualbox = {
    virtualisation.diskSize = 20 * 1024;
    image.fileName = lib.mkForce "k3s-token-lab.ova";
  };

  system.stateVersion = "26.05";
}
