#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# ============================================================
# monitorear_logs.sh
# Modulo de monitoreo de logs con deteccion de eventos criticos
# Proyecto Final - Shell Scripting - IDAT 2026-I
# Grupo: Santos, Juarez, Chavez, Taboada
# ============================================================

CARPETA_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$CARPETA_SCRIPT/biblioteca/comun.sh"

mostrar_ayuda() {
    cat <<'EOF'
Uso:
  ./monitorear_logs.sh [--config ruta] [--modo completo|incremental] [--lineas N] [--fuente ruta]

Opciones:
  --config   Archivo de configuracion del proyecto.
  --modo     completo revisa una ventana completa y incremental solo nuevas lineas.
  --lineas   Cantidad de lineas a revisar en modo completo.
  --fuente   Ejecuta el monitoreo solo para un log especifico.
  --help     Muestra esta ayuda.
EOF
}

archivo_config="$ARCHIVO_CONFIG_PREDETERMINADO"
modo_revision=""
lineas_revision=""
fuente_unica=""

# Permitimos elegir modo completo o incremental segun la necesidad de la prueba.
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)
            archivo_config=$2
            shift 2
            ;;
        --modo)
            modo_revision=$2
            shift 2
            ;;
        --lineas)
            lineas_revision=$2
            shift 2
            ;;
        --fuente)
            fuente_unica=$2
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

# Verificamos que esten disponibles las herramientas que necesitamos para el analisis.
exigir_comando awk
exigir_comando tail
exigir_comando wc
exigir_archivo_lectura "$ARCHIVO_PATRONES"

if [[ -n "$fuente_unica" ]]; then
    FUENTES_LOG=("$fuente_unica")
fi

[[ ${#FUENTES_LOG[@]} -gt 0 ]] || terminar_con_error "No se definieron archivos de log para revisar."
modo_revision=${modo_revision:-$MODO_ESCANEO_PREDETERMINADO}
lineas_revision=${lineas_revision:-$LINEAS_REVISION_PREDETERMINADAS}

[[ "$modo_revision" =~ ^(completo|incremental)$ ]] || terminar_con_error "El modo debe ser completo o incremental."
[[ "$lineas_revision" =~ ^[0-9]+$ ]] || terminar_con_error "El valor de --lineas debe ser numerico."

id_actual="$(id_ejecucion)"
fecha_ejecucion="$(marca_tiempo)"
archivo_ejecucion="$CARPETA_ESTADO/alertas_corrida_${id_actual}.tsv"
archivo_resumen="$CARPETA_REPORTES/resumen_monitoreo_${id_actual}.txt"
archivo_resumen_reciente="$CARPETA_REPORTES/ultimo_resumen_monitoreo.txt"
archivo_resumen_modulo="$CARPETA_REPORTES/ultimo_resumen_modulo_monitoreo.txt"
archivo_alertas="$CARPETA_REPORTES/alertas_${id_actual}.tsv"

: > "$archivo_ejecucion"

revisar_fuente() {
    local ruta_fuente=$1
    local nombre_fuente linea_inicio total_lineas archivo_estado ultima_linea archivo_trabajo

    nombre_fuente=$(basename "$ruta_fuente")
    archivo_estado=$(archivo_checkpoint "$ruta_fuente")

    if [[ ! -f "$ruta_fuente" || ! -r "$ruta_fuente" ]]; then
        registrar_advertencia "Se omite $(ruta_corta "$ruta_fuente") porque no existe o no tiene permisos de lectura."
        return
    fi

    total_lineas=$(contar_lineas "$ruta_fuente")
    linea_inicio=1

    # Si estamos en modo incremental, arrancamos desde donde quedamos la ultima vez.
    if [[ "$modo_revision" == "incremental" && -f "$archivo_estado" ]]; then
        ultima_linea=$(cut -d'|' -f1 "$archivo_estado")
        if [[ "$ultima_linea" =~ ^[0-9]+$ ]] && (( total_lineas >= ultima_linea )); then
            linea_inicio=$((ultima_linea + 1))
        fi
    fi

    if [[ "$modo_revision" == "completo" ]]; then
        linea_inicio=$((total_lineas - lineas_revision + 1))
        if (( linea_inicio < 1 )); then
            linea_inicio=1
        fi
    fi

    printf '%s|%s\n' "$total_lineas" "$fecha_ejecucion" > "$archivo_estado"

    if (( total_lineas == 0 || linea_inicio > total_lineas )); then
        registrar_info "No hay lineas nuevas para $nombre_fuente."
        return
    fi

    archivo_trabajo="$CARPETA_TEMPORAL/revision_$(nombre_seguro "$nombre_fuente")_${id_actual}.log"
    tail -n +"$linea_inicio" "$ruta_fuente" > "$archivo_trabajo"

    # Limpiamos caracteres de control que a veces traen los logs para evitar falsos positivos.
    sed -i 's/\x1b\[[0-9;]*m//g' "$archivo_trabajo"

    if [[ ! -s "$archivo_trabajo" ]]; then
        registrar_info "No se encontro contenido util en $nombre_fuente."
        return
    fi

    # Los patrones se cargan desde un archivo aparte para que sea facil agregar o quitar reglas.
    awk -F'|' -v OFS='\t' \
        -v ruta_fuente="$ruta_fuente" \
        -v nombre_fuente="$nombre_fuente" \
        -v fecha_ejecucion="$fecha_ejecucion" '
        BEGIN {
            IGNORECASE = 1
            cantidad_patrones = 0
        }
        FNR == NR {
            if ($0 ~ /^[[:space:]]*#/ || NF < 4) {
                next
            }
            cantidad_patrones++
            severidad[cantidad_patrones] = $1
            objetivo[cantidad_patrones] = tolower($2)
            expresion[cantidad_patrones] = $3
            descripcion[cantidad_patrones] = $4
            next
        }
        {
            linea = $0
            gsub(/\t/, " ", linea)
            fuente_minuscula = tolower(nombre_fuente)

            for (i = 1; i <= cantidad_patrones; i++) {
                if (objetivo[i] != ".*" && fuente_minuscula !~ objetivo[i]) {
                    continue
                }

                if (linea ~ expresion[i]) {
                    print fecha_ejecucion, severidad[i], ruta_fuente, expresion[i], descripcion[i], linea
                }
            }
        }
    ' "$ARCHIVO_PATRONES" "$archivo_trabajo" >> "$archivo_ejecucion"

    registrar_info "Fuente revisada: $nombre_fuente"
}

for ruta_log in "${FUENTES_LOG[@]}"; do
    revisar_fuente "$ruta_log"
done

# Guardamos los resultados de esta corrida y tambien los acumulamos en el historial.
cp "$archivo_ejecucion" "$archivo_alertas"
cat "$archivo_ejecucion" >> "$ARCHIVO_HISTORIAL_ALERTAS"

total_alertas=$(contar_lineas "$archivo_ejecucion")
alertas_criticas=$(awk -F'\t' '$2 == "CRITICAL" { n++ } END { print n + 0 }' "$archivo_ejecucion")
alertas_altas=$(awk -F'\t' '$2 == "HIGH" { n++ } END { print n + 0 }' "$archivo_ejecucion")
alertas_medias=$(awk -F'\t' '$2 == "MEDIUM" { n++ } END { print n + 0 }' "$archivo_ejecucion")
alertas_bajas=$(awk -F'\t' '$2 == "LOW" { n++ } END { print n + 0 }' "$archivo_ejecucion")

{
    imprimir_separador
    echo "MONITOREO DE LOGS - RESUMEN DE EJECUCION"
    imprimir_separador
    imprimir_dato "Proyecto" "$NOMBRE_PROYECTO"
    imprimir_dato "Entorno" "$NOMBRE_ENTORNO"
    imprimir_dato "Fecha de ejecucion" "$fecha_ejecucion"
    imprimir_dato "Modo de revision" "$modo_revision"
    imprimir_dato "Lineas evaluadas" "$lineas_revision"
    imprimir_dato "Fuentes" "${#FUENTES_LOG[@]}"
    imprimir_dato "Alertas totales" "$total_alertas"
    imprimir_dato "Alertas criticas" "$alertas_criticas"
    imprimir_dato "Alertas altas" "$alertas_altas"
    imprimir_dato "Alertas medias" "$alertas_medias"
    imprimir_dato "Alertas bajas" "$alertas_bajas"
    echo
    echo "Detalle por fuente:"
    if [[ -s "$archivo_ejecucion" ]]; then
        awk -F'\t' -v raiz="$RAIZ_PROYECTO/" '{ ruta=$3; gsub(raiz, "", ruta); acumulado[ruta]++ } END { for (fuente in acumulado) printf " - %s: %d alertas\n", fuente, acumulado[fuente] }' "$archivo_ejecucion" | sort
        echo
        echo "Eventos criticos detectados:"
        awk -F'\t' -v raiz="$RAIZ_PROYECTO/" '$2 == "CRITICAL" { ruta=$3; gsub(raiz, "", ruta); printf " - %s | %s | %s\n", $1, ruta, $6 }' "$archivo_ejecucion" | head -n 5
    else
        echo " - No se detectaron eventos en esta corrida."
    fi
} > "$archivo_resumen"

cp "$archivo_resumen" "$archivo_resumen_reciente"
cp "$archivo_resumen" "$archivo_resumen_modulo"
cat "$archivo_resumen"

# Si se encontraron alertas criticas, devolvemos un codigo de salida diferente para que otro script pueda tomar accion.
if (( alertas_criticas >= UMBRAL_SALIDA_CRITICA )); then
    registrar_advertencia "Se detectaron alertas criticas. El script devolvera codigo 2."
    exit 2
fi

registrar_info "Modulo de monitoreo finalizado sin alertas criticas."
