nix-filter:
{ config, lib, pkgs, ... }:
let name = "hypr-window-switcher";
in {
  options.programs.${name} = { enable = lib.mkEnableOption name; };
  config = lib.mkIf config.programs.${name}.enable {
    environment.systemPackages = [
      # FUTURE: selected nushell
      (pkgs.callPackage ./hypr-window-switcher-package.nix {
        inherit nix-filter;
      })
    ];
  };
}
