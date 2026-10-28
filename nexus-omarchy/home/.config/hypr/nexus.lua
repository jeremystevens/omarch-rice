-- NEXUS window rules. Loaded from hyprland.lua after the other user files.

-- Scratch terminal (~/.config/nexus/bin/nexus-scratch). Only windows with this
-- exact app-id are affected; normal terminals keep their usual placement.
o.window("nexus\\.scratch", {
  workspace = "special:nexus",
  float = true,
  size = { "(monitor_w*0.86)", "(monitor_h*0.74)" },
  center = true,
  tag = "+terminal",   -- so Omarchy's SUPER C / SUPER V copy and paste as in a terminal
})
