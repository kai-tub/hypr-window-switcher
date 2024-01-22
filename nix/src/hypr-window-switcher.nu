#!/usr/bin/env nu
use std log

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
let windows = ^hyprctl -j clients 
  | from json 
  | where hidden == false and monitor != -1
  | sort-by --reverse focusHistoryID address # ensure that current window comes last

# Ordering might be unintuitive. With this set-up if I frequently switch between three windows,
# and have many more, than those that I infrequently visit will always match first

# could also be derived from focushistory
# but I guess this isn't documented behavior
let active_window = ^hyprctl -j activewindow | from json
let current_address = $active_window | get address

let selected = $windows
  | each {
    |r| 
    # use rofi icon string
    $"[($r.workspace.name)] ($r.title) | ($r.class)\u{0}icon\u{1f}($r.class)"
  } 
  | str join "\n"
  | ^fuzzel --dmenu --index

if ($selected | is-empty) {
  log info "nothing selected; quitting"
  return 0
}

let selected_idx = $selected | into int
let selected_window = $windows | get $selected_idx
let selected_address = $selected_window | get address

if $selected_address == ($current_address) {
  # maybe log?
  log info 'already focused; exiting'
  return 0
}

let swallowing_full_screen_windows = $windows
  | where {
    |r|
    $r.workspace.name == $selected_window.workspace.name and $r.fullscreen == true and $r.address != $selected_window.address
  }

let cmd = $swallowing_full_screen_windows
  | get address
  | reduce --fold "" {|it, acc| $"dispatch focuswindow address:($it); dispatch fullscreen 0; " ++ $acc }
  | ($in ++ $"dispatch focuswindow address:($selected_address); dispatch movecursortocorner 3")

log info $"About to execute hyprctl --batch ($cmd)"
$cmd | ^hyprctl --batch $in

