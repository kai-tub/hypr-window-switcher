{ config, lib, pkgs, nix-filter, ... }:
let name = "hypr-window-switcher";
in {
  options.${name} = { enable = lib.mkEnableOption name; };
  config = lib.mkIf config.${name}.enable {
    environment.systemPackages = [
      pkgs.callPackage
      ./hypr-window-switcher-package
      # FUTURE: selected nushell
      { inherit nix-filter; }
    ];
  };
}
