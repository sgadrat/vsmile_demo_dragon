#!/bin/bash

set -e

asm="${NAKEN_BIN:-naken_asm}"

# Build sprites' tileset from spritesheets
tools/build_sprites.py data/spritesheets/player.png > data/sprites.built.bin

# Build backgrounds
tools/compile_backgrounds.py data/backgrounds/index.toml data/backgrounds/

# Build sounds
tools/compile_sounds.py data/audio/index.toml data/audio/

# Assemble the game
"$asm" -l -type bin game.asm -o rgp_demo.bin
