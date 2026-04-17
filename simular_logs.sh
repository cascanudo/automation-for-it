#!/usr/bin/env bash
# simular_logs.sh -- genera lineas de log falsas para probar el monitoreo.
# Escenarios:
#   base     -> solo INFO (no deberia disparar criticas)
#   critico  -> errores y accesos fallidos
#   mixto    -> mezcla, es el que usamos en la sustentacion

set -euo pipefail
IFS=$'\n\t'

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/biblioteca/comun.sh"

usage() {
    cat <<'EOF'
uso: simular_logs.sh [--config ruta] [--escenario base|critico|mixto] [--reset]
EOF
}

archivo_config="$ARCHIVO_CONFIG_PREDETERMINADO"
escenario="mixto"
reset=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)    archivo_config=$2; shift 2 ;;
        --escenario) escenario=$2; shift 2 ;;
        --reset)     reset=true; shift ;;
        --help|-h)   usage; exit 0 ;;
        *) terminar_con_error "parametro invalido: $1" ;;
    esac
done

cargar_configuracion "$archivo_config"
inicializar_entorno

app="$RAIZ_PROYECTO/logs_prueba/app.log"
auth="$RAIZ_PROYECTO/logs_prueba/auth.log"
asegurar_directorio "$RAIZ_PROYECTO/logs_prueba"

if es_si "$reset"; then
    : > "$app"
    : > "$auth"
    rm -f "$CARPETA_CHECKPOINTS"/*.estado 2>/dev/null || true
    : > "$ARCHIVO_HISTORIAL_ALERTAS"
fi

put() {
    # put <archivo> <mensaje>
    printf '%s %s\n' "$(marca_tiempo)" "$2" >> "$1"
}

case "$escenario" in
    base)
        put "$app"  "INFO aplicacion iniciada sin novedades"
        put "$app"  "INFO latido del servicio correcto"
        put "$auth" "INFO acceso del usuario analista exitoso"
        ;;
    critico)
        put "$app"  "ERROR database unavailable on primary cluster"
        put "$app"  "WARN api timeout calling billing service"
        put "$auth" "Failed password for admin from 10.10.5.20 port 22"
        put "$auth" "root login denied from 10.10.5.20"
        ;;
    mixto)
        put "$app"  "INFO despliegue iniciado correctamente"
        put "$app"  "WARN cache timeout reaching redis node"
        put "$app"  "ERROR database unavailable during checkout"
        put "$app"  "deprecated config key legacy_mode=true"
        put "$auth" "INFO acceso de cuenta de servicio correcto"
        put "$auth" "invalid user oracle from 172.16.0.8"
        put "$auth" "Failed password for root from 172.16.0.9 port 22"
        ;;
    *) terminar_con_error "escenario no soportado: $escenario" ;;
esac

registrar_info "logs sembrados ($escenario)"
imprimir_dato "Log de aplicacion"    "$(ruta_corta "$app")"
imprimir_dato "Log de autenticacion" "$(ruta_corta "$auth")"
