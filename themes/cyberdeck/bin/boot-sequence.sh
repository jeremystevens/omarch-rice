#!/bin/bash
# CYBER//DECK fake BIOS boot log — cosmetic only, runs once per session start.

cyan="\e[38;2;0;229;255m"
green="\e[38;2;57;255;140m"
dim="\e[38;2;90;116;128m"
reset="\e[0m"

clear
printf "${cyan}CYBER//DECK BIOS 6.2${reset}\n\n"
sleep 0.4

steps=(
  "MEMORY BANK"
  "NETWORK INTERFACE"
  "DISPLAY SERVER"
  "CRYPTO MODULE"
  "USER PROFILE"
)

for step in "${steps[@]}"; do
  printf "${dim}[${green} OK ${dim}]${reset} %s\n" "$step"
  sleep 0.22
done

sleep 0.3
printf "\n${cyan}OMARCHY${reset} :: INITIALIZING CYBERDECK...\n"
sleep 0.6
printf "${green}ACCESS GRANTED${reset}\n"
sleep 0.7
clear

exec bash -l
