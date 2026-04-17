#!/usr/bin/env bash
# instalar.sh -- da permisos y verifica dependencias.
# No modifica nada del sistema, solo prepara el repo recien clonado.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> otorgando permiso de ejecucion"
chmod +x "$HERE"/*.sh "$HERE"/biblioteca/*.sh

echo "==> verificando dependencias"
faltan=()
for cmd in bash tar awk sed grep find sort wc date chmod mkdir; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        faltan+=("$cmd")
    fi
done

if (( ${#faltan[@]} > 0 )); then
    echo "faltan comandos: ${faltan[*]}" >&2
    exit 1
fi

ver_bash=$(bash --version | head -1)
echo "==> $ver_bash"

if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
    echo "AVISO: ni sha256sum ni shasum disponibles, usaremos cksum (menos robusto)"
fi

if ! command -v crontab >/dev/null 2>&1; then
    echo "AVISO: crontab no esta instalado; programar_tareas.sh mostrara el bloque para copiar a mano"
fi

echo "==> listo. proxima parada:"
echo "    ./ejecutar_todo.sh --escenario mixto --alcance-roles laboratorio --etiqueta final"
