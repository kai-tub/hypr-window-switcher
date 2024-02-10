{
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
    , nixos-shell, }@inputs:
    let
      lib = nixpkgs.lib;
      eachSystem = lib.genAttrs (import systems);
      pkgsFor = eachSystem (system: nixpkgs.legacyPackages.${system});
      filter = nix-filter.lib;
    in {
      # Forward inputs so that the module has access to everything!
      nixosModules.hypr-window-switcher = import ./nix/module.nix inputs;
      nixosModules.default = self.nixosModules.hypr-window-switcher;
      formatter = eachSystem (system: pkgsFor.${system}.nixfmt);
      checks = eachSystem
        (system: { "integrationTest" = self.packages.${system}.test; });
      packages = eachSystem (system:
        let pkgs = pkgsFor.${system};
        in {
          "hypr-window-switcher" =
            pkgs.callPackage ./nix/hypr-window-switcher-package.nix {
              nix-filter = filter;
            };
          default = self.packages.${system}."hypr-window-switcher";

          # inspired by:
          # https://github.com/NixOS/nixpkgs/blob/master/nixos/tests/sway.nix
          test = pkgs.nixosTest {
            name = "test";
            nodes = let user = "alice";
            in {
              node = { config, pkgs, ... }: {
                imports = [
                  home-manager.nixosModules.home-manager
                  self.nixosModules.default
                ];
                boot.kernelPackages = pkgs.linuxPackages;
                programs.hyprland = { enable = true; };
                programs.hypr-window-switcher = {
                  enable = true;
                  extra_dispatches = [ "dispatch movecursortocorner 2" ];
                };
                # user account generation
                users.users = {
                  "${user}" = {
                    isNormalUser = true;
                    extraGroups = [ "networkmanager" "wheel" ];
                    password = "alice";
                    uid = 1000;
                  };
                };
                services.getty.autologinUser = user;
                programs.bash.loginShellInit = ''
                  if [ "$(tty)" = "/dev/tty1" ]; then
                    set -e

                    Hyprland
                  fi
                '';
                environment = {
                  # systemPackages = with pkgs; [ mesa-demos foot ];
                  variables = {
                    # Seems to work without any issues for me!
                    # ok, calling glxinfo does report that there is an error with the
                    # zink renderer but it feels like it is hardware accellerated
                    "WLR_RENDERER" = "pixman";
                    "WLR_RENDERER_ALLOW_SOFTWARE" = "1";
                  };
                };
                # but keyboard input to start switcher and to input logic
                # FUTURE: Does the gpu option also work on github?
                # Just set it manually in Hyprland config works best
                # virtualisation.resolution = { x = 1920; y = 1024; };
                virtualisation.qemu.options =
                  [ "-vga none -device virtio-gpu-pci" ];
                # FUTURE: maybe I should create tmpfiles
                # /tmp/hypr for home-manager instance
                # didn't work
                # systemd.tmpfiles.rules = [ "/tmp/hypr d - - -" ];

                home-manager.users.${user} = {
                  home.username = user;
                  home.homeDirectory = "/home/${user}";
                  wayland.windowManager.hyprland = {
                    enable = true;
                    settings = {
                      "$mod" = "CTRL_SHIFT";
                      "bind" = [
                        "$mod, Q, exec, foot"
                        "$mod, W, exec, hypr-window-switcher"
                        "$mod, F, fullscreen, 1"
                        "$mod, 1, workspace, 1"
                        "$mod, 2, workspace, 2"
                        "$mod, 3, workspace, 3"
                      ];
                      debug = { disable_logs = false; };
                      misc = {
                        "force_default_wallpaper" = 0; # disable anime
                        disable_hyprland_logo = 1;
                        # "disable_splash_rendering" = 1; # this breaks it somehow
                      };
                      "animations" = {
                        enabled = false;
                        first_launch_animation = false;
                      };
                      # if I want to have high-res debugging:
                      # "monitor" = [ ", 1920x1080, auto, 1" ];
                    };
                  };
                  home.stateVersion = "24.05";
                };
              };
            };
            skipLint = false;
            # let
            # user = nodes.machine.config.users.users.alice;
            # bus = "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${
            #     toString user.uid
            #   }/bus";
            # in ''
            testScript = ''
              def safe_screenshot(name):
                node.sleep(3)
                node.screenshot(name)
                node.sleep(3)

              def execute_window_switcher(chars: str):
                # Start the hypr-window-switcher
                node.send_key("ctrl-shift-w")
                # but as it is an overlay, it won't be listed in `clients` or `activewindow`
                # Instead I need to wait until the fuzzel binary has been started
                node.wait_until_succeeds("pgrep fuzzel", timeout=10)
                # there is a tiny delay from starting the binary, until it is focused by hyprland
                node.sleep(1)
                node.send_chars(chars)
                # # needs a bit to show the new focused window

              def mk_cmd_is_active_window(initial_class):
                return f"systemd-run \
                  --machine alice@ \
                  --user \
                  --wait \
                   ${pkgs.nushell}/bin/nu --no-config-file --commands \
                    '${pkgs.hyprland}/bin/hyprctl activewindow -j \
                    | from json \
                    | get initialClass? \
                    | $in == {initial_class} \
                    | match $in {{ true => {{ exit 0 }}, false => {{ exit 1 }} }}' \
                "

              def mk_cmd_is_fullscreen(initial_class):
                return f"systemd-run \
                  --machine alice@ \
                  --user \
                  --wait \
                   ${pkgs.nushell}/bin/nu --no-config-file --commands \
                    '${pkgs.hyprland}/bin/hyprctl clients -j \
                    | from json \
                    | where {{ |r| $r.initialClass == {initial_class} }} \
                    | get fullscreen.0 \
                    | match $in {{ true => {{ exit 0 }}, false => {{ exit 1 }} }}' \
                "

              def mk_cmd_is_empty():
                return "systemd-run \
                  --machine alice@ \
                  --user \
                  --wait \
                   ${pkgs.nushell}/bin/nu --no-config-file --commands \
                      '${pkgs.hyprland}/bin/hyprctl activewindow -j | from json | is-empty | match $in { true => {exit 0}, false => {exit 1} }'\
                "

              def mk_cmd_start_foot(app_id):
                return f"systemd-run \
                  --machine alice@ \
                  --user \
                  --service-type=exec \
                  ${pkgs.foot}/bin/foot --app-id {app_id}"

              node.start()

              with subtest("Starting Hyprland"):
                node.wait_for_unit("multi-user.target")
                # Wait for Hyprland to complete startup:
                node.wait_for_file("/run/user/1000/wayland-1")
                # wait_for_unit cannot be used as it fails on 'in-active' state!
                node.wait_until_succeeds("systemctl --machine alice@ --user is-active hyprland-session.target", 60)
                node.send_key("ctrl-shift-1") # Force workspace-1 just because we can

              with subtest("Starting two terminals called `first` and `second`"):
                # start first terminal
                node.succeed(mk_cmd_start_foot("first"))
                # check if first is in focus
                node.wait_until_succeeds(mk_cmd_is_active_window("first"), 60)
                # start second terminal
                node.succeed(mk_cmd_start_foot("second"))

              with subtest("Ensure that `second` is focused"):
                node.wait_until_succeeds(mk_cmd_is_active_window("second"), 60)

              with subtest("Switch to `first` via `hypr-window-switcher`"):
                execute_window_switcher("first\n")
                node.wait_until_succeeds(mk_cmd_is_active_window("first"), 60)

              # Simple test that cycles between both windows by selecting the default one
              # Starting with focus on `first` from previous test
              with subtest("Ensure that current active window isn't the default selection"):
                node.wait_until_succeeds(mk_cmd_is_active_window("first"), 60)
                execute_window_switcher("\n")
                node.wait_until_succeeds(mk_cmd_is_active_window("second"), 60)
                execute_window_switcher("\n")
                node.wait_until_succeeds(mk_cmd_is_active_window("first"), 60)

              # Starting with focus on `first`
              with subtest("Ensure switcher can be called on empty workspace"):
                node.wait_until_succeeds(mk_cmd_is_active_window("first"), 60)
                node.send_key("ctrl-shift-3")
                node.wait_until_succeeds(mk_cmd_is_empty(), 60)
                # safe_screenshot("empty-workspace.png")
                # assuming that new workspace doesn't have activewindow
                execute_window_switcher("first\n")
                node.wait_until_succeeds(mk_cmd_is_active_window("first"), 60)
                # safe_screenshot("switched-workspace.png")

              with subtest("Ensure switcher undoes fullscreen, if target window is covered by fullscreen"):
                node.wait_until_succeeds(mk_cmd_is_active_window("first"), 60)
                node.send_key("ctrl-shift-f")
                node.wait_until_succeeds(mk_cmd_is_fullscreen("first"), 60)
                # safe_screenshot("fullscreen.png")
                execute_window_switcher("second\n")
                node.wait_until_fails(mk_cmd_is_fullscreen("first"), 60)
                # safe_screenshot("not-fullscreen.png")

              node.shutdown()
            '';
          };
        });
      devShells = eachSystem (system:
        let pkgs = pkgsFor.${system};
        in {
          default = pkgs.mkShell {
            name = "env";
            buildInputs = [ pkgs.stdenv ];
          };
        });
    };
}
