#!/usr/bin/env nu
use std log

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

# Could simply use dmenu and assume that correct
# tool is symlinked to the name. Then it should work with more tools!
# But I would have to re-parse the selected text and match it against the
# table that produced the text...
# Nah, the tool should provide an index option, otherwise, I won't consider it
# I would also have to disable embedding the icon-theme.

# Inspired by:
# https://github.com/hyprwm/Hyprland/discussions/830
# monitor = -1 if monitor becomes unavailable while using the WM
# classic issue with my thunderbold docks...
# TODO: Assert structure of JSON!
let windows = do {^hyprctl -j clients} 
  | complete
  | check "hyprctl" | get stdout
  | from json 
  | where hidden == false and monitor != -1
  | sort-by --reverse focusHistoryID address # ensure that current window comes last

log debug $"windows:\n($windows | select address hidden workspace.id class pinned floating focusHistoryID | table)"


# Ordering might be unintuitive. With this set-up if I frequently switch between three windows,
# and have many more, than those that I infrequently visit will always match first

# could also be derived from focushistory
# but I guess this isn't documented behavior
# TODO: I am assuming that if an empty workspace is opened, this doesn't return anything!
let active_window = do { ^hyprctl -j activewindow } | complete | check "hyprctl" | get stdout | from json
log debug $"active_window class: ($active_window.class)"
let current_address = $active_window | get address?

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

if ($current_address | is-empty) {
  log debug 'Currently there is no active window'
} else {
  if ($selected_address == $current_address) {
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
  | ($in ++ $"dispatch focuswindow address:($selected_address); dispatch movecursortocorner 3")

log debug $"About to execute hyprctl --batch ($cmd)"
do {
  $cmd | ^hyprctl --batch $in
} | complete | check "hyprctl" 


