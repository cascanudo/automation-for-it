#!/usr/bin/env bash
# ============================================================
# generar_reporte_logs.sh
# Reporte diario consolidado del monitoreo de logs
# Proyecto Final - Shell Scripting - IDAT 2026-I
# Grupo: Santos, Juarez, Chavez, Taboada
# ============================================================
# Toma los eventos detectados en una fecha y arma un reporte
# con el desglose por severidad, las fuentes mas activas y
# los hallazgos mas repetidos. Tambien puede generar un
# paquete comprimido con la evidencia del dia.

set -euo pipefail
IFS=$'\n\t'

CARPETA_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$CARPETA_SCRIPT/biblioteca/comun.sh"

mostrar_ayuda() {
    cat <<'EOF'
Uso:
  ./generar_reporte_logs.sh [--config ruta] [--fecha YYYY-MM-DD] [--top N] [--con-respaldo]

Opciones:
  --config        Archivo de configuracion del proyecto.
  --fecha         Fecha a consolidar.
  --top           Cantidad de hallazgos principales a mostrar.
  --con-respaldo  Comprime el reporte junto con el historial del dia.
  --help          Muestra esta ayuda.
EOF
}

archivo_config="$ARCHIVO_CONFIG_PREDETERMINADO"
fecha_objetivo=""
maximo_detalles=5
crear_respaldo=""

# Permite regenerar el reporte para otra fecha si el docente lo pide durante la sustentacion.
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)
            archivo_config=$2
            shift 2
            ;;
        --fecha)
            fecha_objetivo=$2
            shift 2
            ;;
        --top)
            maximo_detalles=$2
            shift 2
            ;;
        --con-respaldo)
            crear_respaldo=true
            shift
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

# Verificamos que las herramientas que usamos para filtrar y consolidar esten disponibles.
exigir_comando awk
exigir_comando grep
exigir_comando sort
exigir_comando tar

fecha_objetivo=${fecha_objetivo:-$(fecha_actual)}
crear_respaldo=${crear_respaldo:-$GENERAR_RESPALDO_REPORTE}
[[ "$maximo_detalles" =~ ^[0-9]+$ ]] || terminar_con_error "El valor de --top debe ser numerico."

archivo_filtrado="$CARPETA_TEMPORAL/alertas_${fecha_objetivo}.tsv"
archivo_reporte="$CARPETA_REPORTES/reporte_logs_${fecha_objetivo}.txt"
archivo_reporte_reciente="$CARPETA_REPORTES/ultimo_reporte_logs.txt"

# Sacamos solo los eventos del dia que nos interesa para no mezclar con otros dias.
grep "^$fecha_objetivo" "$ARCHIVO_HISTORIAL_ALERTAS" > "$archivo_filtrado" || true

# Contamos las alertas por severidad para tener un resumen rapido del dia.
# Usamos sed para limpiar posibles tabuladores extra que puedan venir en el historial.
sed -i 's/\t\t*/\t/g' "$archivo_filtrado" 2>/dev/null || true
total_alertas=$(contar_lineas "$archivo_filtrado")
alertas_criticas=$(awk -F'\t' '$2 == "CRITICAL" { n++ } END { print n + 0 }' "$archivo_filtrado")
alertas_altas=$(awk -F'\t' '$2 == "HIGH" { n++ } END { print n + 0 }' "$archivo_filtrado")
alertas_medias=$(awk -F'\t' '$2 == "MEDIUM" { n++ } END { print n + 0 }' "$archivo_filtrado")
alertas_bajas=$(awk -F'\t' '$2 == "LOW" { n++ } END { print n + 0 }' "$archivo_filtrado")

{
    imprimir_separador
    echo "REPORTE DIARIO DEL MONITOREO DE LOGS"
    imprimir_separador
    imprimir_dato "Proyecto" "$NOMBRE_PROYECTO"
    imprimir_dato "Fecha del reporte" "$fecha_objetivo"
    imprimir_dato "Entorno" "$NOMBRE_ENTORNO"
    imprimir_dato "Alertas totales" "$total_alertas"
    imprimir_dato "Criticas" "$alertas_criticas"
    imprimir_dato "Altas" "$alertas_altas"
    imprimir_dato "Medias" "$alertas_medias"
    imprimir_dato "Bajas" "$alertas_bajas"
    echo

    echo "1. Resumen"
    if (( total_alertas == 0 )); then
        echo " - En la fecha evaluada no se detectaron eventos de riesgo."
    elif (( alertas_criticas > 0 )); then
        echo " - Se encontraron eventos criticos que deben atenderse primero."
    else
        echo " - Hubo actividad relevante, pero sin criticidad maxima."
    fi
    echo

    echo "2. Fuentes con mayor actividad"
    if [[ -s "$archivo_filtrado" ]]; then
        awk -F'\t' -v raiz="$RAIZ_PROYECTO/" '{ ruta=$3; gsub(raiz, "", ruta); totales[ruta]++ } END { for (fuente in totales) printf "%07d\t%s\n", totales[fuente], fuente }' "$archivo_filtrado" | sort -r | head -n "$maximo_detalles" | awk -F'\t' '{ printf " - %s alertas en %s\n", $1 + 0, $2 }'
    else
        echo " - No hubo fuentes con actividad registrada."
    fi
    echo

    echo "3. Hallazgos mas repetidos"
    if [[ -s "$archivo_filtrado" ]]; then
        awk -F'\t' '{ totales[$5]++ } END { for (hallazgo in totales) printf "%07d\t%s\n", totales[hallazgo], hallazgo }' "$archivo_filtrado" | sort -r | head -n "$maximo_detalles" | awk -F'\t' '{ printf " - %s ocurrencias de %s\n", $1 + 0, $2 }'
    else
        echo " - No hay hallazgos para consolidar."
    fi
    echo

    echo "4. Evidencia critica"
    if [[ -s "$archivo_filtrado" ]]; then
        awk -F'\t' -v raiz="$RAIZ_PROYECTO/" '$2 == "CRITICAL" { ruta=$3; gsub(raiz, "", ruta); printf " - %s | %s | %s\n", $1, ruta, $6 }' "$archivo_filtrado" | head -n "$maximo_detalles"
    else
        echo " - No se registraron alertas criticas."
    fi
    echo

    echo "5. Recomendaciones"
    if (( alertas_criticas > 0 )); then
        echo " - Revisar accesos, endurecer credenciales y validar integridad de servicios."
    fi
    if (( alertas_altas > 0 )); then
        echo " - Priorizar la revision de errores de aplicacion y dependencias externas."
    fi
    if (( alertas_medias > 0 )); then
        echo " - Atender las advertencias antes de que escalen a un problema mayor."
    fi
    if (( total_alertas == 0 )); then
        echo " - Mantener la automatizacion activa y conservar evidencia del monitoreo."
    fi
} > "$archivo_reporte"

if es_verdadero "$crear_respaldo"; then
    # El respaldo opcional permite llevarse una copia compacta de la evidencia generada.
    archivo_bundle="$CARPETA_RESPALDOS/paquete_logs_${fecha_objetivo}.tar.gz"
    tar -czf "$archivo_bundle" -C "$RAIZ_PROYECTO" "reportes/$(basename "$archivo_reporte")" "estado/$(basename "$ARCHIVO_HISTORIAL_ALERTAS")"
    registrar_info "Se genero el paquete comprimido del reporte de logs."
fi

cp "$archivo_reporte" "$archivo_reporte_reciente"
cat "$archivo_reporte"
registrar_info "Reporte de monitoreo generado correctamente."