# hypr-window-switcher

Do you love [Hyprland](https://hyprland.org/), the awesome tiling compositor, and the flexibility and configuration it offers,
but are missing a simple tool to switch to a specific window quickly?
Maybe `hypr-window-switcher` is what you are looking for!

https://github.com/kai-tub/hypr-window-switcher/assets/46302524/8cd187e4-31e7-4bbf-a4da-38e89352684c

`hypr-window-switcher` is a tiny script that wraps around [fuzzel](https://codeberg.org/dnkl/fuzzel)
to list all currently open windows, making it easy to switch to the desired window using _fzuzy_ matching!
`hypr-window-switcher` will also take care of those pesky hidden windows and still work as expected, even when the desired window is hidden behind a fullscreen window. ;)

## Installation

The project's repository provides a [NixOS](https://nixos.org/) module, making it a breeze to install
and configure:

```nix
inputs = {
  # ...your inputs
  hypr-window-switcher = "github:kai-tub/hypr-window-switcher";
};
outputs = {
  # ...your outputs
  hypr-window-switcher
}:
# skipping until your main config:
  imports = [
    # ... your imports
    hypr-window-switcher.nixosModules.default
  ];
  # simply enable it to install it!
  programs.hypr-window-switcher = {
    enable = true;
    # Move cursor to the lower-right corner after focus
    extra_dispatches = [ "dispatch movecursortocorner 2" ];
  };
  # Then you can add the command `hypr-window-switcher`
  # to your Hyprland keybindings!
```

However, if you're not a `NixOS` user, you'll have to install the following dependencies manually:

- [fuzzel](https://codeberg.org/dnkl/fuzzel)
- [nushell](https://www.nushell.sh/)

Then, copy the repository's script from the `src` directory to a directory that is [accessible by your `PATH`](https://astrobiomike.github.io/unix/modifying_your_path).

## Configuration

To allow customizing the `hyprctl batch` call, 
_additional_ [hyprctl dispatch commands](https://wiki.hyprland.org/Configuring/Dispatchers/#list-of-dispatchers)
can be configured to run _after_ switching to the target window.
For example:
```
dispatch movecursortocorner 1;
```
can be used to move the cursor to the lower-right corner of the newly focused window.

### Configuration -- NixOS
The `programs.hypr-window-switcher` module provides the module option
`extra_dispatches` that expects a list of strings of dispatch commands, like:
`programs.hypr-window-switcher.extra_dispatches = ["dispatch movecursortocorner 1"];`

### Configuration -- Manual
`hypr-window-switcher` will try to read a _single line_ from the
`~/$XDG_CONFIG_HOME/hypr-window-switcher/extra_dispatches.txt` (default `~/.config/...`)
UTF-8 encoded file or if this file cannot be found from
`/etc/hypr-window-switcher/extra_dispatches.txt`.
The contents of the file might look like:
```
dispatch movecursortocorner 1;
```

## Testing
NixOS VM tests are used to ensure that the script works as expected.
The test will start a VM with a fresh NixOS install and run a _real_ Hyprland session
in the background. Different Wayland applications will be started _within_ the VM, 
and the test script will check if the `hypr-window-switcher` correctly focuses on the entered
target window. Resulting in a _real_ integration test :tada:
See the `flake.nix` file for more details.

## ToDo:
- [ ] Potentially use `bubblewrap` to provide a safer/stricter execution
- [ ] Maybe move to IP C instead of manually invoking `hyprctl`
