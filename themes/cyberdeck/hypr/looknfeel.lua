-- CYBER//DECK look'n'feel: sharp HUD edges, neon glow, dramatic focus contrast,
-- fast cinematic motion. Overlays on top of Omarchy's defaults.

hl.config({
  general = {
    gaps_in = 3,
    gaps_out = 6,
    border_size = 3,
  },

  decoration = {
    rounding = 0,

    dim_inactive = true,
    dim_strength = 0.42,
    inactive_opacity = 0.88,

    -- Soft diffuse bloom in the accent color, not a skeuomorphic drop
    -- shadow — reads as the focused window's border glowing off the screen.
    shadow = {
      enabled = true,
      range = 34,
      render_power = 4,
      color = "rgba(00e5ffcc)",
    },

    blur = {
      enabled = true,
      size = 7,
      passes = 3,
      new_optimizations = true,
      ignore_opacity = true,
    },
  },
})

-- Workspaces are disabled by default upstream; enabling this is what makes
-- switching feel like sliding between control panels instead of an instant cut.
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.1, bezier = "easeOutQuint", style = "slidefade 20%" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 1.7, bezier = "easeOutQuint", style = "popin 85%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 0.8, bezier = "linear", style = "popin 85%" })
hl.animation({ leaf = "fade", enabled = true, speed = 1.4, bezier = "quick" })
hl.animation({ leaf = "border", enabled = true, speed = 3.2, bezier = "easeOutQuint" })

-- Nothing in stock Omarchy blurs the bar/menu/panels — every layer-shell
-- surface renders fully opaque. Blurring these is what makes the shell read
-- as frosted HUD glass instead of a flat solid UI.
hl.layer_rule({ match = { namespace = "omarchy-bar" }, blur = true })
hl.layer_rule({ match = { namespace = "^(omarchy-menu|omarchy-image-selector|omarchy-emojis|omarchy-clipboard|omarchy-keyboard-panel)$" }, blur = true })
hl.layer_rule({ match = { namespace = "omarchy-notifications" }, blur = true })
hl.layer_rule({ match = { namespace = "omarchy-bar-autohide-trigger" }, blur = true })
