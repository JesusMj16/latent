#!/usr/bin/env bash
# Compila el servidor Haskell, lo arranca y abre la GUI de Python.
# Al cerrar la GUI se apaga el servidor.
set -e
cd "$(dirname "$0")"
mkdir -p build output
echo "Compilando servidor Haskell..."
ghc -isrc -outputdir build -o build/latent-server app/Server.hs > build/compile.log 2>&1 || { cat build/compile.log; exit 1; }
pkill -x latent-server 2>/dev/null || true   # apaga un servidor viejo si quedo vivo
sleep 0.3
./build/latent-server &
SERVER=$!
trap 'kill $SERVER 2>/dev/null' EXIT
sleep 0.5
python3 gui/app.py
