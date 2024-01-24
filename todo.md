- [] Add metadata information like description, author, license, mainProgram
- [] Embed option that allows defining which exact nushell version is used
  - [] Take a look at https://github.com/nix-community/home-manager/blob/master/modules/programs/helix.nix
- [] Potentially add overlay to make it easier to find the package but only if remains possible to define which nushell version to use
- [] Further investigate if it possible to write a Hyprland window switcher simulation test
- [] Understand bug where the window switcher does not open one a 'fresh' and empty work space

## Logging
I do believe that the main script should simply call logging functions with differing levels and print whatever it would like to print.
Remember that output is only generated if the LOG_LEVEL is set and should have almost no impact on the performance.
The wrapping script that calls the main script should have to take care of handling `stderr` and to write the output to a configurable file and setting
the LOG_LEVEL.


