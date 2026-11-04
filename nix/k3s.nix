{ pkgs, ... }: {
  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = toString [
      "--disable=servicelb"
      "--write-kubeconfig-group=k3s"
    ];
  };

  users.users.lab.extraGroups = [
    "k3s"
  ];

  networking.firewall.allowedTCPPorts = [
    6443 # k3s: required so that pods can reach the API server (running on port 6443 by default)
  ];

  environment.systemPackages = with pkgs; [ kubernetes-helm ];
}
