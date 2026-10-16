#!/bin/sh
# Abre o jogo no menu. Atalhos:
#   ./jogar.sh demo    CPU contra CPU direto
#   ./jogar.sh treino  modo treino direto
cd "$(dirname "$0")/jogo" || exit 1
G=../ferramentas/Godot_v4.7.2-stable_linux.x86_64
case "$1" in
	demo|treino|versus|dois) exec $G res://cenas/luta.tscn -- --modo="$1" ;;
	*) exec $G ;;
esac
