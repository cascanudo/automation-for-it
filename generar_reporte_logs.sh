#!/usr/bin/env bash
# generar_reporte_logs.sh
#
# Consolida el historial de alertas de una fecha (por defecto hoy) en un
# reporte legible con resumen, top de fuentes, hallazgos repetidos y
# recomendaciones. Opcional: empaqueta la evidencia en un tar.gz.

set -euo pipefail
IFS=$'\n\t'

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/biblioteca/comun.sh"

activar_trampa_errores

usage() {
    cat <<'EOF'
uso: generar_reporte_logs.sh [--config ruta] [--fecha YYYY-MM-DD]
                             [--top N] [--con-respaldo]
EOF
}

archivo_config="$ARCHIVO_CONFIG_PREDETERMINADO"
fecha=""
top=5
con_respaldo=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)       archivo_config=$2; shift 2 ;;
        --fecha)        fecha=$2; shift 2 ;;
        --top)          top=$2; shift 2 ;;
        --con-respaldo) con_respaldo=true; shift ;;
        --help|-h)      usage; exit 0 ;;
        *) terminar_con_error "parametro invalido: $1" ;;
    esac
done

cargar_configuracion "$archivo_config"
inicializar_entorno

exigir_comando awk
exigir_comando grep
exigir_comando tar

fecha=${fecha:-$(fecha_actual)}
con_respaldo=${con_respaldo:-$GENERAR_RESPALDO_REPORTE}
[[ "$top" =~ ^[0-9]+$ ]] || terminar_con_error "--top debe ser numero"

tmp="$CARPETA_TEMPORAL/alertas_${fecha}.tsv"
out="$CARPETA_REPORTES/reporte_logs_${fecha}.txt"
ultimo="$CARPETA_REPORTES/ultimo_reporte_logs.txt"

grep "^$fecha" "$ARCHIVO_HISTORIAL_ALERTAS" > "$tmp" || true
# normalizamos tabuladores dobles que a veces aparecen cuando el historial
# se edita a mano en ciertos editores de Windows
sed -i 's/\t\t*/\t/g' "$tmp" 2>/dev/null || true

total=$(contar_lineas "$tmp")
declare -A c
for sev in CRITICAL HIGH MEDIUM LOW; do
    c[$sev]=$(awk -F'\t' -v s="$sev" '$2 == s {n++} END {print n + 0}' "$tmp")
done

{
    imprimir_separador
    echo "REPORTE DIARIO DEL MONITOREO DE LOGS"
    imprimir_separador
    imprimir_dato "Proyecto"         "$NOMBRE_PROYECTO"
    imprimir_dato "Fecha del reporte" "$fecha"
    imprimir_dato "Entorno"          "$NOMBRE_ENTORNO"
    imprimir_dato "Alertas totales"  "$total"
    imprimir_dato "Criticas"         "${c[CRITICAL]}"
    imprimir_dato "Altas"            "${c[HIGH]}"
    imprimir_dato "Medias"           "${c[MEDIUM]}"
    imprimir_dato "Bajas"            "${c[LOW]}"
    echo

    echo "1. Resumen"
    if (( total == 0 )); then
        echo " - no se detectaron eventos en la fecha"
    elif (( c[CRITICAL] > 0 )); then
        echo " - hay eventos criticos que deben atenderse primero"
    else
        echo " - hubo actividad relevante pero sin criticidad maxima"
    fi
    echo

    echo "2. Fuentes con mayor actividad"
    if [[ -s "$tmp" ]]; then
        awk -F'\t' -v raiz="$RAIZ_PROYECTO/" '
            { r=$3; gsub(raiz, "", r); a[r]++ }
            END { for (f in a) printf "%07d\t%s\n", a[f], f }
        ' "$tmp" | sort -r | head -n "$top" \
          | awk -F'\t' '{ printf " - %s alertas en %s\n", $1 + 0, $2 }'
    else
        echo " - sin actividad registrada"
    fi
    echo

    echo "3. Hallazgos mas repetidos"
    if [[ -s "$tmp" ]]; then
        awk -F'\t' '
            { a[$5]++ }
            END { for (h in a) printf "%07d\t%s\n", a[h], h }
        ' "$tmp" | sort -r | head -n "$top" \
          | awk -F'\t' '{ printf " - %s ocurrencias de %s\n", $1 + 0, $2 }'
    else
        echo " - nada para consolidar"
    fi
    echo

    echo "4. Evidencia critica"
    if [[ -s "$tmp" ]]; then
        awk -F'\t' -v raiz="$RAIZ_PROYECTO/" '
            $2 == "CRITICAL" { r=$3; gsub(raiz, "", r); printf " - %s | %s | %s\n", $1, r, $6 }
        ' "$tmp" | head -n "$top"
    else
        echo " - no hay alertas criticas"
    fi
    echo

    echo "5. Recomendaciones"
    (( c[CRITICAL] > 0 )) && echo " - revisar accesos, endurecer credenciales y validar integridad de servicios"
    (( c[HIGH]     > 0 )) && echo " - priorizar errores de aplicacion y dependencias externas"
    (( c[MEDIUM]   > 0 )) && echo " - atender advertencias antes de que escalen"
    (( total == 0       )) && echo " - mantener la automatizacion activa y conservar evidencia del monitoreo"
} > "$out"

if es_si "$con_respaldo"; then
    bundle="$CARPETA_RESPALDOS/paquete_logs_${fecha}.tar.gz"
    tar -czf "$bundle" -C "$RAIZ_PROYECTO" \
        "reportes/$(basename "$out")" \
        "estado/$(basename "$ARCHIVO_HISTORIAL_ALERTAS")"
    registrar_info "bundle generado: $(ruta_corta "$bundle")"
fi

cp "$out" "$ultimo"
cat "$out"
registrar_info "reporte diario listo ($total alertas, ${c[CRITICAL]} criticas)"
