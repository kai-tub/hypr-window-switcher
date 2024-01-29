inputs:
{ config, lib, pkgs, ... }:
let
  name = "hypr-window-switcher";
  cfg = config.programs.${name};
in {
  options.programs.${name} = {
    enable = lib.mkEnableOption name;
    nu_package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nushell;
      defaultText = lib.literalExpression "pkgs.nushell";
      description = "The package to use for nushell.";
    };
    fuzzel_package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.fuzzel;
      defaultText = lib.literalExpression "pkgs.fuzzel";
      description = "The package to use for fuzzel.";
    };
  };
  config = lib.mkIf config.programs.${name}.enable {
    environment.systemPackages = [
      # Need to call the package to ensure that I can pass in the
      # options from the module
      (pkgs.callPackage ./hypr-window-switcher-package.nix {
        nix-filter = inputs.self.inputs.nix-filter;
        nuPackage = cfg.nu_package;
        fuzzelPackage = cfg.fuzzel_package;
      })
    ];
  };
}
