#!/usr/bin/env bash
# Construye el lugar jugable y pasa todas las comprobaciones.
#
#   tools/build.sh                 → DontStealThePresent.rbxl (mapa horneado) + comprobaciones
#   API_DUMP=ruta tools/build.sh   → además ejecuta la partida simulada completa
#
# Necesita rojo, lune y selene en el PATH (ver aftman.toml).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build

echo "== Rojo"
rojo build default.project.json -o build/base.rbxl

echo "== Sintaxis"
lune run tools/lune/check.luau src

if command -v selene >/dev/null 2>&1; then
	echo "== Selene"
	selene src tools
fi

echo "== Lógica"
lune run tools/lune/test-logic.luau build/base.rbxl

echo "== Regalos (28 x 6 variantes)"
lune run tools/lune/test-presents.luau build/base.rbxl | tail -n 1

echo "== Mapa horneado"
lune run tools/lune/bake.luau build/base.rbxl DontStealThePresent.rbxl

API_DUMP="${API_DUMP:-build/Full-API-Dump.json}"
if [ -f "$API_DUMP" ]; then
	echo "== Partida simulada"
	lune run tools/sim/run.luau "$API_DUMP" .
else
	echo "(Para la partida simulada descarga Full-API-Dump.json de github.com/MaximumADHD/Roblox-Client-Tracker"
	echo " a build/Full-API-Dump.json o pon su ruta en API_DUMP)"
fi
echo "Listo: DontStealThePresent.rbxl"
