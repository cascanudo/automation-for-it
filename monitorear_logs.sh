#!/usr/bin/env bash
#
# monitorear_logs.sh
#
# Lee los logs definidos en FUENTES_LOG, les aplica las reglas de
# patrones.conf y deja una linea por hallazgo clasificada por severidad.
# Modo completo: ultimas N lineas. Modo incremental: solo lo nuevo.
#
# Salidas relevantes:
#   estado/alertas_corrida_<id>.tsv       -> hallazgos crudos
#   estado/alertas_historial.tsv          -> historial acumulado
#   reportes/resumen_monitoreo_<id>.txt   -> resumen legible
#   reportes/ultimo_resumen_monitoreo.txt -> copia del ultimo resumen
#
# Exit codes:
#   0 sin alertas criticas
#   1 error de ejecucion
#   2 se detectaron alertas criticas (util para encadenar con otros scripts)

set -euo pipefail
IFS=$'\n\t'

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/biblioteca/comun.sh"

activar_trampa_errores

usage() {
    cat <<'EOF'
uso: monitorear_logs.sh [--config ruta] [--modo completo|incremental]
                        [--lineas N] [--fuente ruta]
EOF
}

archivo_config="$ARCHIVO_CONFIG_PREDETERMINADO"
modo=""
lineas=""
fuente=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)  archivo_config=$2; shift 2 ;;
        --modo)    modo=$2; shift 2 ;;
        --lineas)  lineas=$2; shift 2 ;;
        --fuente)  fuente=$2; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) terminar_con_error "parametro invalido: $1" ;;
    esac
done

cargar_configuracion "$archivo_config"
inicializar_entorno

exigir_comando awk
exigir_comando tail
exigir_archivo_lectura "$ARCHIVO_PATRONES"

# TODO(max): mover este check a comun.sh cuando sumemos mas archivos de reglas
lineas_validas=$(grep -Evc '^[[:space:]]*(#|$)' "$ARCHIVO_PATRONES" || true)
(( lineas_validas > 0 )) || terminar_con_error "patrones.conf no tiene reglas activas"

[[ -n "$fuente" ]] && FUENTES_LOG=("$fuente")
(( ${#FUENTES_LOG[@]} > 0 )) || terminar_con_error "no hay fuentes de log definidas"

modo=${modo:-$MODO_ESCANEO_PREDETERMINADO}
lineas=${lineas:-$LINEAS_REVISION_PREDETERMINADAS}

[[ "$modo" =~ ^(completo|incremental)$ ]] || terminar_con_error "modo debe ser completo|incremental"
[[ "$lineas" =~ ^[0-9]+$ ]] || terminar_con_error "--lineas debe ser numero"

id="$(id_ejecucion)"
ahora="$(marca_tiempo)"

out_corrida="$CARPETA_ESTADO/alertas_corrida_${id}.tsv"
out_alertas="$CARPETA_REPORTES/alertas_${id}.tsv"
out_resumen="$CARPETA_REPORTES/resumen_monitoreo_${id}.txt"
resumen_ultimo="$CARPETA_REPORTES/ultimo_resumen_monitoreo.txt"
resumen_modulo="$CARPETA_REPORTES/ultimo_resumen_modulo_monitoreo.txt"

: > "$out_corrida"

# --- logica de una fuente ---
revisar_fuente() {
    local ruta=$1
    local nombre total estado inicio tmp ultima

    nombre=$(basename "$ruta")
    estado=$(archivo_checkpoint "$ruta")

    if [[ ! -r "$ruta" ]]; then
        registrar_advertencia "salto $(ruta_corta "$ruta") (sin lectura)"
        return
    fi

    total=$(contar_lineas "$ruta")
    inicio=1

    if [[ "$modo" == "incremental" && -f "$estado" ]]; then
        ultima=$(cut -d'|' -f1 "$estado")
        if [[ "$ultima" =~ ^[0-9]+$ ]] && (( total >= ultima )); then
            inicio=$((ultima + 1))
        fi
    fi

    if [[ "$modo" == "completo" ]]; then
        inicio=$(( total - lineas + 1 ))
        (( inicio < 1 )) && inicio=1
    fi

    printf '%s|%s\n' "$total" "$ahora" > "$estado"

    if (( total == 0 || inicio > total )); then
        registrar_info "sin lineas nuevas en $nombre"
        return
    fi

    tmp="$CARPETA_TEMPORAL/revision_$(nombre_seguro "$nombre")_${id}.log"
    tail -n +"$inicio" "$ruta" > "$tmp"

    # quitamos escapes ANSI: los hemos visto meter ruido al regex
    sed -i 's/\x1b\[[0-9;]*m//g' "$tmp"

    [[ -s "$tmp" ]] || { registrar_info "nada util en $nombre"; return; }

    # awk con dos entradas: primero los patrones, despues la ventana de log.
    # FNR==NR indica que todavia estamos en el primer archivo (patrones).
    awk -F'|' -v OFS='\t' \
        -v ruta_fuente="$ruta" \
        -v nombre_fuente="$nombre" \
        -v cuando="$ahora" '
        BEGIN { IGNORECASE = 1; n = 0 }
        FNR == NR {
            if ($0 ~ /^[[:space:]]*#/ || NF < 4) next
            n++
            sev[n]  = $1
            obj[n]  = tolower($2)
            rx[n]   = $3
            desc[n] = $4
            next
        }
        {
            line = $0
            gsub(/\t/, " ", line)
            low = tolower(nombre_fuente)
            for (i = 1; i <= n; i++) {
                if (obj[i] != ".*" && low !~ obj[i]) continue
                if (line ~ rx[i]) {
                    print cuando, sev[i], ruta_fuente, rx[i], desc[i], line
                }
            }
        }
    ' "$ARCHIVO_PATRONES" "$tmp" >> "$out_corrida"

    registrar_info "revise $nombre ($((total - inicio + 1)) lineas)"
}

for ruta_log in "${FUENTES_LOG[@]}"; do
    revisar_fuente "$ruta_log"
done

cp "$out_corrida" "$out_alertas"
cat "$out_corrida" >> "$ARCHIVO_HISTORIAL_ALERTAS"

total=$(contar_lineas "$out_corrida")
declare -A c
for sev in CRITICAL HIGH MEDIUM LOW; do
    c[$sev]=$(awk -F'\t' -v s="$sev" '$2 == s {n++} END {print n + 0}' "$out_corrida")
done

{
    imprimir_separador
    echo "MONITOREO DE LOGS - RESUMEN DE EJECUCION"
    imprimir_separador
    imprimir_dato "Proyecto"           "$NOMBRE_PROYECTO"
    imprimir_dato "Entorno"            "$NOMBRE_ENTORNO"
    imprimir_dato "Fecha de ejecucion" "$ahora"
    imprimir_dato "Modo de revision"   "$modo"
    imprimir_dato "Lineas evaluadas"   "$lineas"
    imprimir_dato "Fuentes"            "${#FUENTES_LOG[@]}"
    imprimir_dato "Alertas totales"    "$total"
    imprimir_dato "Alertas criticas"   "${c[CRITICAL]}"
    imprimir_dato "Alertas altas"      "${c[HIGH]}"
    imprimir_dato "Alertas medias"     "${c[MEDIUM]}"
    imprimir_dato "Alertas bajas"      "${c[LOW]}"
    echo
    echo "Detalle por fuente:"
    if [[ -s "$out_corrida" ]]; then
        awk -F'\t' -v raiz="$RAIZ_PROYECTO/" '
            { r=$3; gsub(raiz, "", r); a[r]++ }
            END { for (f in a) printf " - %s: %d alertas\n", f, a[f] }
        ' "$out_corrida" | sort
        echo
        echo "Eventos criticos detectados:"
        awk -F'\t' -v raiz="$RAIZ_PROYECTO/" '
            $2 == "CRITICAL" { r=$3; gsub(raiz, "", r); printf " - %s | %s | %s\n", $1, r, $6 }
        ' "$out_corrida" | head -n 5
    else
        echo " - no se detectaron eventos en esta corrida"
    fi
} > "$out_resumen"

cp "$out_resumen" "$resumen_ultimo"
cp "$out_resumen" "$resumen_modulo"
cat "$out_resumen"

if (( c[CRITICAL] >= UMBRAL_SALIDA_CRITICA )); then
    registrar_advertencia "se detectaron ${c[CRITICAL]} alertas criticas -> exit 2"
    exit 2
fi

registrar_info "monitoreo ok (sin criticas)"
