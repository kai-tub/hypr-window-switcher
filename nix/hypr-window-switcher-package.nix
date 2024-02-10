{ pkgs, stdenvNoCC, nix-filter, nuPackage ? pkgs.nushell
, fuzzelPackage ? pkgs.fuzzel, }:
let
  # The following 'internal' script needs access
  # to the binary PATHs. It is easiest to wrap
  # it inside of a writShellApplication derivation
  # as I also want to overlay some 'logic' for handling
  # stdout/stderr.
  script = stdenvNoCC.mkDerivation rec {
    # pname + version could also be an option
    name = "hypr-window-switcher.nu";
    # wrap program could also be used
    # but this allows for easier module management if necessary
    # buildInputs = [ nuPackage ];
    src = nix-filter {
      root = ./src;
      include = [ ./src/hypr-window-switcher.nu ];
    };
    installPhase = ''
      runHook preInstall
      # not copying to `out/bin` because it needs an explicit
      # call from nu!
      # If the script wouldn't contain any external program calls
      # one could simply patch the shebang!
      # patchShebangs --build $out/bin/${name}
      cp $src/hypr-window-switcher.nu $out
      runHook postInstall
    '';
    meta.mainProgram = name;
  };
in pkgs.writeShellApplication rec {
  name = "hypr-window-switcher";
  runtimeInputs = [ script nuPackage fuzzelPackage ];
  text = ''
    NU_LOG_LEVEL=DEBUG nu --no-config-file ${script} &> /tmp/hypr-window-switcher.log
  '';
  meta = {
    description = "A Hyprland keyboard-driven window-switcher.";
    longDescription = ''
      This program interacts with `hyprctl` from `Hyprland` to
      generate a searchable `fuzzel`-based `dmenu` list to switch
      to the target window, while handling variuous corner-cases.
    '';
    homepage = "https://github.com/kai-tub/hypr-window-switcher";
    license = pkgs.lib.licenses.mit;
    mainProgram = name;
  };
}
