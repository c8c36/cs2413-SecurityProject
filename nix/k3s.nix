{ pkgs, ... }: {
  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = toString [
      "--disable=servicelb"
      "--write-kubeconfig-group=k3s"
    ];

    autoDeployCharts = {
      headlamp = {
        name = "headlamp";
        repo = "https://kubernetes-sigs.github.io/headlamp";
        version = "0.46.0";
        hash = "sha256-+qRxqMXFUSWz3O7Rz3MADhztGPB+IIjl4S51KS+5rmI=";

        targetNamespace = "kube-system";
      };
    };
  };

  users.users.lab.extraGroups = [
    "k3s"
  ];

  networking.firewall.allowedTCPPorts = [
    6443 # k3s: required so that pods can reach the API server (running on port 6443 by default)
  ];

  environment.variables = {
    KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
  };

  environment.systemPackages = with pkgs; [ kubernetes-helm ];
}
