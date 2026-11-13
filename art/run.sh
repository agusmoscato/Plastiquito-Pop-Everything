#!/usr/bin/env bash
# Corre un modelo: art/run.sh hand   (genera assets/models/hand.glb y art/renders/hand.jpg)
cd "$(dirname "$0")/.."
BL="${BLENDER:-/c/Program Files/Blender Foundation/Blender 4.5/blender.exe}"
"$BL" -b --factory-startup -P "art/models/$1.py" -- --out "$(pwd)/assets/models/$1.glb" --render "$(pwd)/art/renders" 2>&1 | grep -E "TRIS|Error|Traceback|error|File \"" 
