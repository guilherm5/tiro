#!/usr/bin/env bash
# Roda os testes automáticos (sem janela). Uso: ./tests/rodar_testes.sh
# Os testes ficam fora do jogo (.gdignore) e são executados pelo Godot em modo headless.
GODOT="/home/guilherme/Documentos/central/ferramentas/Godot_v4.7.2-stable_linux.x86_64"
cd "$(dirname "$0")/.." || exit 1
RUIDO='^$|Godot Engine|leaked|at:|still in use|Leaked|PagedAllocator|WARNING|RenderingServer meshes|performance issues|For runtime|GDScript backtrace|\[0\]|dispersão'
for teste in tests/teste_*.gd; do
	echo "== $teste"
	timeout 180 "$GODOT" --headless --path . -s "$PWD/$teste" -- --teste 2>&1 | grep -Ev "$RUIDO"
done
