-- NEXUS look'n'feel.
-- Square 2px borders, no blur or shadows (battery), short shared motion.
-- To turn every animation off: touch ~/.local/state/nexus/reduced-motion.flag

hl.config({
  general = {
    gaps_in = 5,
    gaps_out = 10,
    border_size = 2,
  },

  decoration = {
    rounding = 0,
    dim_inactive = false,
    shadow = { enabled = false },
    blur = { enabled = false },
  },
})

-- One curve for everything: fast out, gentle settle.
hl.curve("nsOut", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })

-- Speeds are in 100 ms units, so everything lands between 120 and 180 ms.
hl.animation({ leaf = "global", enabled = true, speed = 1.6, bezier = "nsOut" })
hl.animation({ leaf = "border", enabled = true, speed = 1.2, bezier = "nsOut" })
hl.animation({ leaf = "windows", enabled = true, speed = 1.6, bezier = "nsOut" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 1.6, bezier = "nsOut", style = "popin 94%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.2, bezier = "nsOut", style = "popin 94%" })
hl.animation({ leaf = "fade", enabled = true, speed = 1.4, bezier = "nsOut" })
hl.animation({ leaf = "layers", enabled = true, speed = 1.4, bezier = "nsOut", style = "fade" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.8, bezier = "nsOut", style = "slidefadevert 12%" })

local reduced = io.open(os.getenv("HOME") .. "/.local/state/nexus/reduced-motion.flag", "r")
if reduced then
  reduced:close()
  hl.config({ animations = { enabled = false } })
end
