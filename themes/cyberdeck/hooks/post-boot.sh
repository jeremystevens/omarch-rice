#!/bin/bash
# Launches the CYBER//DECK boot log once, right after the desktop starts.
foot --app-id cyberdeck-boot -e bash -c "$HOME/.config/omarchy/themes/cyberdeck/bin/boot-sequence.sh" &
disown

paplay "$HOME/.config/omarchy/themes/cyberdeck/sounds/login-chirp.wav" &
disown
