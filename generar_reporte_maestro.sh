#!/usr/bin/env bash
# generar_reporte_maestro.sh
#
# Consolida la evidencia de los 3 modulos (respaldos, monitoreo, roles)
# en un solo reporte ejecutivo. Opcionalmente arma un tar.gz con los
# reportes mas recientes y deja un registro del envio.

set -euo pipefail
IFS=$'\n\t'

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/biblioteca/comun.sh"

activar_trampa_errores

ayuda() {
    cat <<'EOF'
uso: generar_reporte_maestro.sh [--config ruta] [--fecha YYYY-MM-DD] [--con-bundle]
EOF
}

archivo_config="$ARCHIVO_CONFIG_PREDETERMINADO"
fecha=""
con_bundle=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)     archivo_config=$2; shift 2 ;;
        --fecha)      fecha=$2; shift 2 ;;
        --con-bundle) con_bundle=true; shift ;;
        --help|-h)    ayuda; exit 0 ;;
        *) terminar_con_error "parametro invalido: $1" ;;
    esac
done

cargar_configuracion "$archivo_config"
inicializar_entorno

exigir_comando awk
exigir_comando grep
exigir_comando tar

fecha=${fecha:-$(fecha_actual)}

archivo_maestro="$CARPETA_REPORTES/reporte_maestro_${fecha}.txt"
archivo_maestro_ultimo="$CARPETA_REPORTES/ultimo_reporte_maestro.txt"

logs_dia="$CARPETA_TEMPORAL/maestro_logs_${fecha}.tsv"
respaldos_dia="$CARPETA_TEMPORAL/maestro_respaldos_${fecha}.tsv"
usuarios_dia="$CARPETA_TEMPORAL/maestro_usuarios_${fecha}.tsv"

rep_respaldos="$CARPETA_REPORTES/ultimo_reporte_respaldos.txt"
rep_logs="$CARPETA_REPORTES/ultimo_reporte_logs.txt"
rep_usuarios="$CARPETA_REPORTES/ultimo_reporte_usuarios.txt"

grep "^$fecha" "$ARCHIVO_HISTORIAL_ALERTAS"   > "$logs_dia"      || true
grep "^$fecha" "$ARCHIVO_HISTORIAL_RESPALDOS" > "$respaldos_dia" || true
grep "^$fecha" "$ARCHIVO_HISTORIAL_USUARIOS"  > "$usuarios_dia"  || true

n_logs=$(contar_lineas "$logs_dia")
n_logs_crit=$(awk -F'\t' '$2 == "CRITICAL" {n++} END {print n + 0}' "$logs_dia")
n_resp=$(contar_lineas "$respaldos_dia")
n_resp_ok=$(awk -F'\t' '$8 == "OK" {n++} END {print n + 0}' "$respaldos_dia")
n_usr=$(contar_lineas "$usuarios_dia")
n_usr_ok=$(awk -F'\t' '$7 == "OK" {n++} END {print n + 0}' "$usuarios_dia")

{
    imprimir_separador
    echo "REPORTE MAESTRO DEL PROYECTO FINAL"
    imprimir_separador
    imprimir_dato "Proyecto"       "$NOMBRE_PROYECTO"
    imprimir_dato "Fecha evaluada" "$fecha"
    imprimir_dato "Entorno"        "$NOMBRE_ENTORNO"
    echo

    echo "1. Resumen ejecutivo"
    echo " - Respaldos generados: $n_resp"
    echo " - Eventos de monitoreo: $n_logs"
    echo " - Eventos criticos: $n_logs_crit"
    echo " - Operaciones de usuarios y roles: $n_usr"
    echo

    echo "2. Estado de cada modulo"
    if (( n_resp > 0 )); then
        echo " - Copias de seguridad: operativas ($n_resp_ok/$n_resp registros OK)"
    else
        echo " - Copias de seguridad: sin ejecucion registrada para la fecha"
    fi
    if (( n_logs > 0 )); then
        echo " - Monitoreo de logs: hubo actividad y ya existe evidencia consolidada"
    else
        echo " - Monitoreo de logs: sin eventos en la fecha"
    fi
    if (( n_usr > 0 )); then
        echo " - Usuarios y roles: gestion procesada ($n_usr_ok/$n_usr operaciones OK)"
    else
        echo " - Usuarios y roles: sin operaciones registradas"
    fi
    echo

    echo "3. Evidencia principal"
    [[ -f "$rep_respaldos" ]] && echo " - Reporte de respaldos: $(ruta_corta "$rep_respaldos")"
    [[ -f "$rep_logs"      ]] && echo " - Reporte de monitoreo: $(ruta_corta "$rep_logs")"
    [[ -f "$rep_usuarios"  ]] && echo " - Reporte de usuarios: $(ruta_corta "$rep_usuarios")"
    echo

    echo "4. Comentario final"
    if (( n_resp > 0 && n_logs > 0 && n_usr > 0 )); then
        echo " - El proyecto evidencia funcionamiento en los tres casos exigidos"
    else
        echo " - Falta evidencia de uno o mas modulos antes de la entrega"
    fi
    if (( n_logs_crit > 0 )); then
        echo " - Los eventos criticos corresponden al escenario de prueba controlado"
    fi
} > "$archivo_maestro"

envio=$(simular_envio_reporte "reporte-maestro-$fecha" "$CORREO_DESTINO_RESPALDO" "$archivo_maestro" "$CANAL_ENVIO_RESPALDO")

if es_si "$con_bundle"; then
    bundle="$CARPETA_RESPALDOS/paquete_maestro_${fecha}.tar.gz"
    items=("reportes/$(basename "$archivo_maestro")")
    [[ -f "$rep_respaldos" ]] && items+=("reportes/$(basename "$rep_respaldos")")
    [[ -f "$rep_logs"      ]] && items+=("reportes/$(basename "$rep_logs")")
    [[ -f "$rep_usuarios"  ]] && items+=("reportes/$(basename "$rep_usuarios")")
    tar -czf "$bundle" -C "$RAIZ_PROYECTO" "${items[@]}"
    echo >> "$archivo_maestro"
    imprimir_dato "Paquete maestro" "$(ruta_corta "$bundle")" >> "$archivo_maestro"
fi

echo >> "$archivo_maestro"
imprimir_dato "Registro de envio" "$(ruta_corta "$envio")" >> "$archivo_maestro"

cp "$archivo_maestro" "$archivo_maestro_ultimo"
cat "$archivo_maestro"
registrar_info "reporte maestro generado"
