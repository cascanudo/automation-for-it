#!/usr/bin/env bash
# copias_seguridad.sh -- respaldos diarios con manifiesto y reporte.

set -euo pipefail
IFS=$'\n\t'

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/biblioteca/comun.sh"

activar_trampa_errores

ayuda() {
    cat <<'EOF'
uso: copias_seguridad.sh [--config ruta] [--etiqueta nombre] [--retencion N] [--fuente ruta]

  --config     archivo .conf del proyecto
  --etiqueta   nombre del lote (default: diario)
  --retencion  cuantos lotes historicos conservar
  --fuente     respalda solo esa carpeta (ignora FUENTES_RESPALDO)
  --help       esta ayuda
EOF
}

archivo_config="$ARCHIVO_CONFIG_PREDETERMINADO"
etiqueta="diario"
retencion=""
fuente_unica=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)    archivo_config=$2; shift 2 ;;
        --etiqueta)  etiqueta=$2; shift 2 ;;
        --retencion) retencion=$2; shift 2 ;;
        --fuente)    fuente_unica=$2; shift 2 ;;
        --help|-h)   ayuda; exit 0 ;;
        *) terminar_con_error "parametro no reconocido: $1" ;;
    esac
done

cargar_configuracion "$archivo_config"
inicializar_entorno

exigir_comando tar
exigir_comando find
exigir_comando awk

if [[ -n "$fuente_unica" ]]; then
    FUENTES_RESPALDO=("$fuente_unica")
fi

(( ${#FUENTES_RESPALDO[@]} > 0 )) || terminar_con_error "no hay carpetas en FUENTES_RESPALDO"

retencion=${retencion:-$MAXIMO_LOTES_RESPALDO}
[[ "$retencion" =~ ^[0-9]+$ ]] || terminar_con_error "--retencion debe ser numero"

id="$(id_ejecucion)"
ahora="$(marca_tiempo)"
lote="$CARPETA_RESPALDOS/lote_respaldo_${id}"
manifiesto="$lote/manifiesto_respaldo.tsv"
reporte="$CARPETA_REPORTES/reporte_respaldo_${id}.txt"
reporte_ultimo="$CARPETA_REPORTES/ultimo_reporte_respaldos.txt"

asegurar_directorio "$lote"
: > "$manifiesto"

pkgs=0; n_archivos=0; bytes=0; ok=0; omitidas=0

for origen in "${FUENTES_RESPALDO[@]}"; do
    nombre=$(basename "$origen")
    # sanitizamos sin lanzar sed: expansion bash sirve perfecto aca
    nombre=${nombre//[^a-zA-Z0-9._-]/_}

    if [[ ! -d "$origen" ]]; then
        registrar_advertencia "omito $(ruta_corta "$origen") (no existe)"
        printf '%s\t%s\t%s\t-\t0\t0\t-\tOMITIDO\n' "$ahora" "$etiqueta" "$origen" >> "$ARCHIVO_HISTORIAL_RESPALDOS"
        omitidas=$((omitidas + 1))
        continue
    fi

    paquete="$lote/${etiqueta}_${nombre}_${id}.tar.gz"
    tar -czf "$paquete" -C "$(dirname "$origen")" "$nombre"

    archivos=$(find "$origen" -type f | wc -l | tr -d '[:space:]')
    peso=$(wc -c < "$paquete" | tr -d '[:space:]')
    hash=$(calcular_hash "$paquete")

    printf '%s\t%s\t%s\t%s\t%s\t%s\tOK\n' \
        "$origen" "$paquete" "$archivos" "$peso" "$hash" "$etiqueta" >> "$manifiesto"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\tOK\n' \
        "$ahora" "$etiqueta" "$origen" "$paquete" "$archivos" "$peso" "$hash" >> "$ARCHIVO_HISTORIAL_RESPALDOS"

    pkgs=$((pkgs + 1))
    n_archivos=$((n_archivos + archivos))
    bytes=$((bytes + peso))
    ok=$((ok + 1))
done

envio=$(simular_envio_reporte "reporte-respaldo-$id" "$CORREO_DESTINO_RESPALDO" "$reporte" "$CANAL_ENVIO_RESPALDO")

{
    imprimir_separador
    echo "COPIAS DE SEGURIDAD DIARIAS - REPORTE DE EJECUCION"
    imprimir_separador
    imprimir_dato "Proyecto"            "$NOMBRE_PROYECTO"
    imprimir_dato "Fecha de ejecucion"  "$ahora"
    imprimir_dato "Etiqueta del lote"   "$etiqueta"
    imprimir_dato "Carpeta del lote"    "$(ruta_corta "$lote")"
    imprimir_dato "Fuentes evaluadas"   "${#FUENTES_RESPALDO[@]}"
    imprimir_dato "Paquetes generados"  "$pkgs"
    imprimir_dato "Archivos respaldados" "$n_archivos"
    imprimir_dato "Tamano total"        "$bytes bytes"
    imprimir_dato "Fuentes correctas"   "$ok"
    imprimir_dato "Fuentes omitidas"    "$omitidas"
    imprimir_dato "Registro de envio"   "$(ruta_corta "$envio")"
    echo
    echo "Detalle por carpeta:"
    if [[ -s "$manifiesto" ]]; then
        awk -F'\t' -v raiz="$RAIZ_PROYECTO/" '
            { gsub(raiz, "", $1); gsub(raiz, "", $2);
              printf " - %s => %s | archivos=%s | bytes=%s\n", $1, $2, $3, $4 }
        ' "$manifiesto"
    else
        echo " - no se generaron respaldos"
    fi
} > "$reporte"

cp "$reporte" "$reporte_ultimo"

# Retencion: conservamos solo los ultimos N lotes.
shopt -s nullglob
lotes=("$CARPETA_RESPALDOS"/lote_respaldo_*)
if (( ${#lotes[@]} > retencion )); then
    mapfile -t ordenados < <(printf '%s\n' "${lotes[@]}" | sort -r)
    for viejo in "${ordenados[@]:retencion}"; do
        rm -rf "$viejo"
    done
fi
shopt -u nullglob

cat "$reporte"
registrar_info "respaldos ok ($pkgs paquetes, $bytes bytes)"
