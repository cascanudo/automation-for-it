#!/usr/bin/env bash
# programar_tareas.sh -- instala/quita/ver las entradas de cron del proyecto.
#
# Acciones: instalar | quitar | ver (default: ver)
#
# Tareas:
#   02:00     respaldo diario
#   */15 min  monitoreo incremental
#   06:15     auditoria de roles (simulacion)
#   23:55     reporte maestro con bundle

set -euo pipefail
IFS=$'\n\t'

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/biblioteca/comun.sh"

ayuda() {
    cat <<'EOF'
uso: programar_tareas.sh [instalar|quitar|ver] [--config ruta]
EOF
}

accion="${1:-ver}"
(( $# > 0 )) && shift

archivo_config="$ARCHIVO_CONFIG_PREDETERMINADO"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)  archivo_config=$2; shift 2 ;;
        --help|-h) ayuda; exit 0 ;;
        *) terminar_con_error "opcion no reconocida: $1" ;;
    esac
done

cargar_configuracion "$archivo_config"
inicializar_entorno

# construimos las lineas con la etiqueta como comentario final para poder
# desinstalarlas despues sin borrar cron del usuario.
ent_respaldo="0 2 * * * cd \"$RAIZ_PROYECTO\" && /usr/bin/env bash \"$RAIZ_PROYECTO/copias_seguridad.sh\" --config \"$archivo_config\" --etiqueta diario >> \"$CARPETA_REPORTES/cron_respaldos.log\" 2>&1 # ${ETIQUETA_CRON}-respaldos"
ent_monitoreo="*/15 * * * * cd \"$RAIZ_PROYECTO\" && /usr/bin/env bash \"$RAIZ_PROYECTO/monitorear_logs.sh\" --config \"$archivo_config\" --modo incremental >> \"$CARPETA_REPORTES/cron_monitoreo.log\" 2>&1 # ${ETIQUETA_CRON}-monitoreo"
ent_roles="15 6 * * * cd \"$RAIZ_PROYECTO\" && /usr/bin/env bash \"$RAIZ_PROYECTO/gestionar_roles.sh\" --config \"$archivo_config\" --alcance auto --simular >> \"$CARPETA_REPORTES/cron_roles.log\" 2>&1 # ${ETIQUETA_CRON}-roles"
ent_maestro="55 23 * * * cd \"$RAIZ_PROYECTO\" && /usr/bin/env bash \"$RAIZ_PROYECTO/generar_reporte_maestro.sh\" --config \"$archivo_config\" --con-bundle >> \"$CARPETA_REPORTES/cron_maestro.log\" 2>&1 # ${ETIQUETA_CRON}-maestro"

if ! command -v crontab >/dev/null 2>&1; then
    cat <<EOF
cron no esta disponible en este entorno (pasa seguido en WSL sin servicio)
Copia este bloque a mano con: crontab -e

$ent_respaldo
$ent_monitoreo
$ent_roles
$ent_maestro
EOF
    exit 0
fi

actual="$(crontab -l 2>/dev/null || true)"

case "$accion" in
    instalar)
        {
            printf '%s\n' "$actual" | grep -v "$ETIQUETA_CRON" || true
            printf '%s\n' "$ent_respaldo"
            printf '%s\n' "$ent_monitoreo"
            printf '%s\n' "$ent_roles"
            printf '%s\n' "$ent_maestro"
        } | crontab -
        registrar_info "cron instalado con etiqueta $ETIQUETA_CRON"
        ;;
    quitar)
        printf '%s\n' "$actual" | grep -v "$ETIQUETA_CRON" | crontab -
        registrar_info "cron limpiado"
        ;;
    ver)
        printf '%s\n' "$actual" | grep "$ETIQUETA_CRON" \
            || echo "no hay tareas cron del proyecto"
        ;;
    *) ayuda; exit 1 ;;
esac
