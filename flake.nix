{
  description = "Minimal NixOS lab";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  outputs =
    { self, nixpkgs }:
    let
      makeSystem = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./nix/k3s.nix
          ./nix/system-virtualbox.nix
        ];
      };
    in
    {
      virtualbox-vm = (makeSystem).config.system.build.images.virtualbox;
    };
}
