#!/bin/sh
echo -ne '\033c\033]0;Roleplay Rebirth\a'
base_path="$(dirname "$(realpath "$0")")"
"$base_path/Roleplay Rebirth.x86_64" "$@"
