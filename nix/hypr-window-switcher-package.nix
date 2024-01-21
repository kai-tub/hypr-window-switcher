{ pkgs, stdenvNoCC, nix-filter, nuPackage ? pkgs.nushell }:
stdenvNoCC.mkDerivation rec {
  name = "hypr-window-switcher";
  # Maybe think about if it is necessary to add fuzzel as a dependency
  # but if I do so, then I would technically have to add a wrapper around it
  # Maybe this would be something wrapProgram could take care of?
  buildInputs = [ nuPackage ];
  src = nix-filter {
    root = ./src;
    include = [ ./src/hypr-window-switcher.nu ];
  };
  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    # cp $src/src/hypr-window-switcher.nu $out/bin/${name}
    cp $src/hypr-window-switcher.nu $out/bin/${name}
    patchShebangs --build $out/bin/${name}
    runHook postInstall
  '';
}
