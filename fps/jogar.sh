#!/usr/bin/env bash
# Roda o jogo direto, sem abrir o editor.
GODOT="/home/guilherme/Documentos/central/ferramentas/Godot_v4.7.2-stable_linux.x86_64"
cd "$(dirname "$0")" && exec "$GODOT" --path .
