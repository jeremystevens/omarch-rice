#!/bin/bash
cyan="\e[38;2;0;229;255m"
green="\e[38;2;57;255;140m"
amber="\e[38;2;255;176;32m"
dim="\e[38;2;90;116;128m"
reset="\e[0m"

operator=${USER^^}

if curl -fsS --max-time 2 -o /dev/null https://1.1.1.1; then
  network="ONLINE"
else
  network="UNSTABLE"
fi

threats=("Probably DNS" "None detected" "A rogue cron job" "Unconfirmed" "Just the neighbor's WiFi")
coffee=("CRITICALLY LOW" "NOMINAL" "BREWING" "EMPTY — SEND HELP" "TOPPED OFF")
grandpa=("UNSUPERVISED" "WATCHING TV" "ASLEEP" "PLOTTING SOMETHING" "FINE, PROBABLY")

pick() { local arr=("$@"); echo "${arr[$RANDOM % ${#arr[@]}]}"; }

printf "${cyan}CYBER//DECK STATUS${reset}\n"
printf "${dim}────────────────────────${reset}\n"
printf "${dim}%-13s${reset}${green}%s${reset}\n" "Operator" "$operator"
printf "${dim}%-13s${reset}${green}%s${reset}\n" "Security" "NOMINAL"
printf "${dim}%-13s${reset}%b%s${reset}\n" "Network" "$([[ $network == ONLINE ]] && echo "$green" || echo "$amber")" "$network"
printf "${dim}%-13s${reset}${amber}%s${reset}\n" "Coffee" "$(pick "${coffee[@]}")"
printf "${dim}%-13s${reset}%s\n" "Threats" "$(pick "${threats[@]}")"
printf "${dim}%-13s${reset}%s\n" "Grandpa BB" "$(pick "${grandpa[@]}")"
