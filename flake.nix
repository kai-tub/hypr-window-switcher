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
      # partially apply nix-filter
      nixosModules.hypr-window-switcher = import ./nix/module.nix nix-filter;
      nixosModules.default = self.nixosModules.hypr-window-switcher;
      packages = eachSystem (system:
        let pkgs = pkgsFor.${system};
        in {
          "hypr-window-switcher" =
            pkgs.callPackage ./nix/hypr-window-switcher-package.nix {
              nix-filter = filter;
            };
          "hypr-window-switcher-runner" = pkgs.writeShellApplication {
            name = "hypr-window-switcher-runner";
            runtimeInputs = [ self.packages.${system}.hypr-window-switcher ];
            text = ''
              # create log directory where the logs will be written to
              NU_LOG_LEVEL=DEBUG hypr-window-switcher &> /tmp/hypr-window-switcher.log
            '';
          };
          default = self.packages.${system}."hypr-window-switcher";

          # https://github.com/NixOS/nixpkgs/blob/master/nixos/tests/sway.nix
          test = pkgs.nixosTest ({
            name = "test";
            nodes = let user = "alice";
            in {
              node = { config, pkgs, ... }: {
                imports = [ home-manager.nixosModules.home-manager ];
                boot.kernelPackages = pkgs.linuxPackages;
                programs.hyprland = { enable = true; };
                # user account generation
                users.users = {
                  "${user}" = {
                    isNormalUser = true;
                    extraGroups = [ "networkmanager" "wheel" ];
                    password = "alice";
                    # TODO: set id
                  };
                };
                services.getty.autologinUser = user;
                programs.bash.loginShellInit = ''
                  if [ "$(tty)" = "/dev/tty1" ]; then
                    set -e

                    Hyprland && touch /tmp/hyprland-exit-ok
                  fi
                '';
                environment = {
                  systemPackages = with pkgs; [ alacritty fuzzel mesa-demos ];
                  variables = {
                    # Seems to work without any issues for me!
                    # ok, calling glxinfo does report that there is an error with the
                    # zink renderer but it feels like it is hardware accellerated
                    "WLR_RENDERER" = "pixman";
                    "WLR_RENDERER_ALLOW_SOFTWARE" = "1";
                  };
                };
                # services.xserver.resolution = [ {
                #   x = 1920;
                #   y = 1080;
                # }];
                # TODO: Make test with my new qemu window rule
                # that pretends to always fullscreen the application!
                virtualisation.resolution = {
                  x = 1920;
                  y = 1024;
                };
                virtualisation.qemu.options =
                  [ "-vga none -device virtio-gpu-pci" ];
                home-manager.users.${user} = {
                  home.username = user;
                  home.homeDirectory = "/home/${user}";
                  wayland.windowManager.hyprland = {
                    enable = true;
                    settings = {
                      "$mod" = "CTRL_SHIFT";
                      "bind" = "$mod, Q, exec, kitty";
                      "exec-once" = "fuzzel";
                      "monitor" = [ ", 1920x1080, auto, 1" ];
                    };
                  };
                  home.stateVersion = "24.05";
                };
              };
            };
            skipLint = true;
            testScript = ''
              start_all()
              node.wait_for_unit("multi-user.target")
              # To check if Hyprland can be accessed
              # node.succeed("Hyprland --help")
              # Wait for Hyprland to complete startup:
              node.wait_for_file("/run/user/1000/wayland-1")
              # get env echo $HYPRLAND_INSTANCE_SIGNATURE
              # and use that to interpolate to get access to socket
              # node.wait_for_file("/tmp/hypr/SIG/.socket.sock")
              node.sleep(3)
              # Embeds the screenshot into the `./result/` section
              node.screenshot("shot.png")

              # Exit and check exit status
              # node.wait_for_file("/tmp/hyprland-exit-ok")
              node.shutdown()

            '';
          });
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
