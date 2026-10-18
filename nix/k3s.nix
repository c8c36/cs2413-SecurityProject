{ pkgs, ... }: {
  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = toString [
      "--disable=traefik"
      "--disable=servicelb"
    ];
  };

  users.users.lab.extraGroups = [
    "k3s"
  ];

  environment.systemPackages = with pkgs; [ kubectl ];
}
