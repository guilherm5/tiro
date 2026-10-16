#!/usr/bin/env bash
# Abre o projeto no editor do Godot.
GODOT="/home/guilherme/Documentos/central/ferramentas/Godot_v4.7.2-stable_linux.x86_64"
cd "$(dirname "$0")" && exec "$GODOT" --editor --path .
