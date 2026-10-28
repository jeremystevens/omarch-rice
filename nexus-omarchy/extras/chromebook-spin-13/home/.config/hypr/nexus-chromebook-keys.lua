-- Chromebook top row (Acer Spin 13 "Nami"). The kernel has no keymap for this
-- board, so the top row sends plain F1-F10 and the XF86 media bindings never
-- fire. These make each key do what its icon shows. Search (SUPER) + a top-row
-- key sends the real F-key to the app, as on ChromeOS. No F-key was bound before.

-- Same down/up split as Omarchy's universal clipboard keys, so synthetic keys
-- don't stick.
local function nexus_send(mods, key)
  return function()
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
    hl.timer(function()
      hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
    end, { timeout = 50, type = "oneshot" })
  end
end

o.bind("F1", "Back (browser)", nexus_send("", "XF86Back"))
o.bind("F2", "Forward (browser)", nexus_send("", "XF86Forward"))
o.bind("F3", "Reload (browser)", nexus_send("", "XF86Reload"))
o.bind("F4", "Full screen", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
o.bind("F5", "NEXUS command menu", "omarchy-shell nexus menu")
o.bind("SHIFT + F5", "NEXUS search", "omarchy-shell nexus search")
o.bind("ALT + F5", "NEXUS jobs", "omarchy-shell nexus jobs")
o.bind("CTRL + F5", "Screenshot", "omarchy-capture-screenshot")
o.bind("CTRL + SHIFT + F5", "Capture menu (region / recording / OCR)", "omarchy-menu toggle capture")

o.bind("F6", "Brightness down", "omarchy-brightness-display 5%-", { locked = true, repeating = true })
o.bind("F7", "Brightness up", "omarchy-brightness-display +5%", { locked = true, repeating = true })
o.bind("ALT + F6", "Brightness down precise", "omarchy-brightness-display 1%-", { locked = true, repeating = true })
o.bind("ALT + F7", "Brightness up precise", "omarchy-brightness-display +1%", { locked = true, repeating = true })
o.bind("SHIFT + F6", "Brightness minimum", "omarchy-brightness-display 1%", { locked = true })
o.bind("SHIFT + F7", "Brightness maximum", "omarchy-brightness-display 100%", { locked = true })

o.bind("F8", "Mute", "omarchy-audio-output-volume mute-toggle", { locked = true })
o.bind("SHIFT + F8", "Switch audio output", "omarchy-audio-output-switch", { locked = true })
o.bind("F9", "Volume down", "omarchy-audio-output-volume lower", { locked = true, repeating = true })
o.bind("F10", "Volume up", "omarchy-audio-output-volume raise", { locked = true, repeating = true })
o.bind("ALT + F9", "Volume down precise", "omarchy-audio-output-volume -1", { locked = true, repeating = true })
o.bind("ALT + F10", "Volume up precise", "omarchy-audio-output-volume +1", { locked = true, repeating = true })

for n = 1, 10 do
  o.bind("SUPER + F" .. n, "Send F" .. n .. " to the app", nexus_send("", "F" .. n))
end
