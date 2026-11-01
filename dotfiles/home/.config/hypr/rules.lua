-- Personal window rules (omarch-rice/dotfiles; loaded by a block in hyprland.lua).
-- "silent" opens the app on its workspace without taking you there.

-- Chat on 2
o.window("^(org\\.telegram\\.desktop|TelegramDesktop|signal|Signal)$", { workspace = "2 silent" })

-- Editors on 3, the dev workspace
o.window("^(Emacs|emacs|code|Code|com\\.microsoft\\.VSCode)$", { workspace = "3 silent" })

-- Music on 5
o.window("^(spotify|Spotify)$", { workspace = "5 silent" })

-- AI Terminal Companion floats in the middle instead of tiling
o.window("^aiterm$", {
  float = true,
  size = { "(monitor_w*0.7)", "(monitor_h*0.7)" },
  center = true,
})
