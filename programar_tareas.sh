#!/usr/bin/env bash
# ============================================================
# programar_tareas.sh
# Automatizacion con cron para los modulos del proyecto
# Proyecto Final - Shell Scripting - IDAT 2026-I
# Grupo: Santos, Juarez, Chavez, Taboada
# ============================================================
# Configura las entradas de crontab para que los respaldos,
# el monitoreo, la auditoria de roles y el reporte maestro
# se ejecuten de forma automatica. Si cron no esta disponible,
# muestra el bloque recomendado para copiar a mano.

set -euo pipefail
IFS=$'\n\t'

CARPETA_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$CARPETA_SCRIPT/biblioteca/comun.sh"

mostrar_ayuda() {
    cat <<'EOF'
Uso:
  ./programar_tareas.sh [instalar|quitar|ver] [--config ruta]
EOF
}

accion="${1:-ver}"
if [[ $# -gt 0 ]]; then
    shift
fi

archivo_config="$ARCHIVO_CONFIG_PREDETERMINADO"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)
            archivo_config=$2
            shift 2
            ;;
        --help|-h)
            mostrar_ayuda
            exit 0
            ;;
        *)
            terminar_con_error "Parametro no reconocido: $1"
            ;;
    esac
done

cargar_configuracion "$archivo_config"
inicializar_entorno

entrada_respaldo="0 2 * * * cd \"$RAIZ_PROYECTO\" && /usr/bin/env bash \"$RAIZ_PROYECTO/copias_seguridad.sh\" --config \"$archivo_config\" --etiqueta diario >> \"$CARPETA_REPORTES/cron_respaldos.log\" 2>&1 # ${ETIQUETA_CRON}-respaldos"
entrada_monitoreo="*/15 * * * * cd \"$RAIZ_PROYECTO\" && /usr/bin/env bash \"$RAIZ_PROYECTO/monitorear_logs.sh\" --config \"$archivo_config\" --modo incremental >> \"$CARPETA_REPORTES/cron_monitoreo.log\" 2>&1 # ${ETIQUETA_CRON}-monitoreo"
entrada_roles="15 6 * * * cd \"$RAIZ_PROYECTO\" && /usr/bin/env bash \"$RAIZ_PROYECTO/gestionar_roles.sh\" --config \"$archivo_config\" --alcance auto --simular >> \"$CARPETA_REPORTES/cron_roles.log\" 2>&1 # ${ETIQUETA_CRON}-roles"
entrada_maestra="55 23 * * * cd \"$RAIZ_PROYECTO\" && /usr/bin/env bash \"$RAIZ_PROYECTO/generar_reporte_maestro.sh\" --config \"$archivo_config\" --con-bundle >> \"$CARPETA_REPORTES/cron_maestro.log\" 2>&1 # ${ETIQUETA_CRON}-maestro"

if ! command -v crontab >/dev/null 2>&1; then
    cat <<EOF
Cron no esta disponible en este entorno.

Bloque recomendado para Linux:
$entrada_respaldo
$entrada_monitoreo
$entrada_roles
$entrada_maestra
EOF
    exit 0
fi

cron_actual="$(crontab -l 2>/dev/null || true)"

case "$accion" in
    instalar)
        {
            printf '%s\n' "$cron_actual" | grep -v "$ETIQUETA_CRON" || true
            printf '%s\n' "$entrada_respaldo"
            printf '%s\n' "$entrada_monitoreo"
            printf '%s\n' "$entrada_roles"
            printf '%s\n' "$entrada_maestra"
        } | crontab -
        registrar_info "Tareas cron instaladas correctamente."
        ;;
    quitar)
        printf '%s\n' "$cron_actual" | grep -v "$ETIQUETA_CRON" | crontab -
        registrar_info "Tareas cron retiradas."
        ;;
    ver)
        printf '%s\n' "$cron_actual" | grep "$ETIQUETA_CRON" || echo "No hay tareas cron registradas para este proyecto."
        ;;
    *)
        mostrar_ayuda
        exit 1
        ;;
esac
