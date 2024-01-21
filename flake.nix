{
  # description = "A very basic flake";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-colors.url = "github:misterio77/nix-colors";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    systems.url = "github:nix-systems/x86_64-linux";
    nix-filter.url = "github:numtide/nix-filter";
    nixos-shell.url = "github:Mic92/nixos-shell";
  };

  outputs = { self, nixpkgs, nix-colors, home-manager, systems, nix-filter
    , nixos-shell }:
    let
      lib = nixpkgs.lib;
      eachSystem = lib.genAttrs (import systems);
      pkgsFor = eachSystem (system: nixpkgs.legacyPackages.${system});
      filter = nix-filter.lib;
    in {
      nixosModules.hypr-window-switcher =
        import ./nix/module.nix { nix-filter = filter; };
      nixosModules.default = self.hypr-window-switcher;
      packages = eachSystem (system:
        let pkgs = pkgsFor.${system};
        in {
          "hypr-window-switcher" =
            pkgs.callPackage ./nix/hypr-window-switcher-package.nix {
              nix-filter = filter;
            };
          default = self.packages.${system}."hypr-window-switcher";
        });
      devShells = eachSystem (system:
        let pkgs = pkgsFor.${system};
        in {
          default = pkgs.mkShell {
            name = "env";
            buildInputs = [ pkgs.stdenv ];
          };
        });
      nixosConfigurations = eachSystem (system:
        let
          pkgs = pkgsFor.${system};
          user = "alice";
        in lib.makeOverridable lib.nixosSystem {
          inherit system;
          modules = [
            nixos-shell.nixosModules.nixos-shell
            home-manager.nixosModules.home-manager
            {
              boot.kernelPackages = pkgs.linuxPackages_latest;
              nixos-shell.mounts = {
                # can lead to not so nice behavior if combined with home-manager...
                mountHome = false;
              };
              virtualisation.memorySize = 4096;
              services.xserver.enable = true;
              services.xserver.displayManager.sddm = {
                enable = true;
                settings = {
                  # Autologin = {
                  #   Session = "hyprland";
                  #   User = user;
                  # };
                };
              };
              virtualisation.graphics = true;
              users.users = {
                "${user}" = {
                  isNormalUser = true;
                  extraGroups = [ "networkmanager" "wheel" ];
                  password = "root";
                };
              };
              environment.systemPackages = with pkgs; [
                kitty
                fuzzel
                vim
                helix
              ];

              # Cage would be kinda cool if I weren't testing
              # an application that lays on top of other windows...
              # services.cage = {
              #   enable = true;
              #   user = user;
              #   program = "${pkgs.fuzzel}/bin/fuzzel -d --layer=overlay";
              # };

              # virtualisation = {
              #   qemu.options = [ "-vga virtio" ];
              # };
              # https://discourse.nixos.org/t/runtest-getting-a-screenshot-under-sway-greetd-session/27352/3 
              virtualisation.qemu.options =
                [ "-vga none" "-device virtio-gpu-pci" "-display gtk" ];
              # services.xserver.desktopManager.gnome.enable = true;
              programs.hyprland = { enable = true; };
              home-manager.useUserPackages = true;
              # Use the global `pkgs` from teh system level `nixpkgs` option
              # and not a private `pkgs` configuration
              # Again, not really sure what that means
              home-manager.useGlobalPkgs = true;
              home-manager.extraSpecialArgs = { inherit user; };
              # homeConfig = {
              #   mode = "full";
              #   graphical = "minimal";
              # };
              home-manager.users.${user} = {
                home.username = user;
                home.homeDirectory = "/home/${user}";
                wayland.windowManager.hyprland = {
                  enable = true;
                  settings = {
                    "$mod" = "CTRL_SHIFT";
                    "bind" = "$mod, Q, exec, kitty";
                    "exec-once" = "fuzzel";
                  };
                };
                home.stateVersion = "24.05";
              };
            }
          ];
        });
      # packages = eachSystem (system:
      #   let pkgs = pkgsFor.${system};
      #   in {
      #     nixosConfigurations.vm = lib.makeOverridable lib.nixosSystem {
      #       inherit system;
      #       modules = [{
      #         boot.kernelPackages = pkgs.linuxPackages_latest;
      #         services.xserver.enable = true;
      #       }];
      #     };
      #   });
    };
}
