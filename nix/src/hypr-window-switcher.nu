#!/usr/bin/env nu --no-config-file
use std log

log debug (nu version)

# Check output of `complete`
# and raise error if non-zero exit status exists
def check [cmd: string]: {
  let inp = $in
  if $inp.exit_code == 0 {
    return $inp
  } else {
    let stderr = $inp.stderr?
    let msg = if ($stderr | is-empty) {
      $"Command ($cmd) failed"
    } else {
      $"Command ($cmd) failed with:\n($stderr)"
    }
    error make -u {
      msg: $msg
    }
  }
}

# Inspired by:
# https://github.com/hyprwm/Hyprland/discussions/830
# monitor = -1 if monitor becomes unavailable while using the WM
# classic issue with my thunderbold dock...
# FUTURE: Make is safe to run via bubblewrap
let windows = do {^hyprctl -j clients} 
  | complete
  | check "hyprctl" | get stdout
  | from json 
  | where hidden == false and monitor != -1
  | sort-by focusHistoryID 
  | do { let inp = $in; $inp | range 1.. | append $inp.0? } # ensure that current window comes last if any window exists

log debug $"windows:\n($windows | select address hidden workspace.id class pinned floating focusHistoryID | table)"

# there must be a smarter way to handle this path configuration...
let general_config_path = "/etc/hypr-window-switcher/extra_dispatches.txt"
let config_dir = if ($env.XDG_CONFIG_HOME? | is-empty) {
  "~/.config"
} else {
  $env.XDG_CONFIG_HOME
}
let user_config_path = $"($config_dir)/hypr-window-switcher/extra_dispatches.txt" | path expand
let config_path = if ($user_config_path | path exists) {
  log debug "Selecting user-specific config"
  $user_config_path
} else {
  log debug "No user-specific config found"
  $general_config_path
}

let extra_dispatches = if ($config_path | path exists) {
  # only ever read a single line!
  $config_path | open --raw | decode utf-8 | lines | first
} else {
  ""
}

if ($extra_dispatches | is-empty) {
  log debug "No extra dispatchers configured"
} else {
  log debug $"Parsed the following extra dispatches: ($extra_dispatches)"
}

# This cannot be derived from the focushistory as the last focused window isn't necessarily what we are
# currently looking at! It might be an empy work-space for example.
let active_window = do { ^hyprctl -j activewindow } | complete | check "hyprctl" | get stdout | from json

let current_address_maybe = $active_window | get address?

let rofi_out = $windows
  | each {
    |r| 
    # use rofi icon string
    $"[($r.workspace.name)] ($r.title) | ($r.class)\u{0}icon\u{1f}($r.class)"
  } 
  | str join "\n"
  | do { ^fuzzel --dmenu --index }  # wrapping with `do` required to capture stderr!
  | complete 
  | check "fuzzel"

log debug $"Rofi stderr:\n($rofi_out | get stderr?)"

let selected = $rofi_out
  | get stdout

if ($selected | is-empty) {
  log info "nothing selected; quitting"
  return 0
}

let selected_idx = $selected | into int
let selected_window = $windows | get $selected_idx
let selected_address = $selected_window | get address

if ($current_address_maybe | is-empty) {
  log debug 'Currently there is no active window'
} else {
  if ($selected_address == $current_address_maybe) {
    log info 'already focused; exiting'
    return 0
  } else {
    log debug 'will switch to selected window.'
  }
}

let swallowing_full_screen_windows = $windows
  | where {
    |r|
    $r.workspace.name == $selected_window.workspace.name and $r.fullscreen == true and $r.address != $selected_window.address
  }
log debug $'The target window is covered by ($swallowing_full_screen_windows | length) windows. These will be minified.'

let cmd = $swallowing_full_screen_windows
  | get address
  | reduce --fold "" {|it, acc| $"dispatch focuswindow address:($it); dispatch fullscreen 0; " ++ $acc }
  | ($in ++ $"dispatch focuswindow address:($selected_address); ($extra_dispatches)")

log debug $"About to execute hyprctl --batch ($cmd)"
do {
  $cmd | ^hyprctl --batch $in
} | complete | check "hyprctl" 

