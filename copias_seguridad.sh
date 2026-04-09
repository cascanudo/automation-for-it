#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# ============================================================
# copias_seguridad.sh
# Modulo de copias de seguridad diarias con envio de reporte
# Proyecto Final - Shell Scripting - IDAT 2026-I
# Grupo: Santos, Juarez, Chavez, Taboada
# ============================================================

CARPETA_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$CARPETA_SCRIPT/biblioteca/comun.sh"

mostrar_ayuda() {
    cat <<'EOF'
Uso:
  ./copias_seguridad.sh [--config ruta] [--etiqueta nombre] [--retencion N] [--fuente ruta]

Opciones:
  --config     Archivo de configuracion del proyecto.
  --etiqueta   Nombre del lote de respaldo.
  --retencion  Cantidad maxima de lotes historicos a conservar.
  --fuente     Ejecuta el respaldo sobre una sola carpeta.
  --help       Muestra esta ayuda.
EOF
}

archivo_config="$ARCHIVO_CONFIG_PREDETERMINADO"
etiqueta_lote="diario"
maximo_retencion=""
fuente_unica=""

# Primero resolvemos parametros para que el script pueda usarse solo o dentro del proyecto.
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)
            archivo_config=$2
            shift 2
            ;;
        --etiqueta)
            etiqueta_lote=$2
            shift 2
            ;;
        --retencion)
            maximo_retencion=$2
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

# Nos aseguramos de que esten instaladas las herramientas que vamos a necesitar.
exigir_comando tar
exigir_comando find
exigir_comando awk
exigir_comando sort
exigir_comando wc

if [[ -n "$fuente_unica" ]]; then
    FUENTES_RESPALDO=("$fuente_unica")
fi

[[ ${#FUENTES_RESPALDO[@]} -gt 0 ]] || terminar_con_error "No se definieron carpetas para respaldar."
maximo_retencion=${maximo_retencion:-$MAXIMO_LOTES_RESPALDO}
[[ "$maximo_retencion" =~ ^[0-9]+$ ]] || terminar_con_error "El valor de --retencion debe ser numerico."

id_actual="$(id_ejecucion)"
fecha_ejecucion="$(marca_tiempo)"
carpeta_lote="$CARPETA_RESPALDOS/lote_respaldo_${id_actual}"
archivo_manifiesto="$carpeta_lote/manifiesto_respaldo.tsv"
archivo_reporte="$CARPETA_REPORTES/reporte_respaldo_${id_actual}.txt"
archivo_reporte_reciente="$CARPETA_REPORTES/ultimo_reporte_respaldos.txt"

cantidad_paquetes=0
cantidad_archivos=0
bytes_totales=0
cantidad_ok=0
cantidad_omitidas=0

asegurar_directorio "$carpeta_lote"
: > "$archivo_manifiesto"

# Aca recorremos cada carpeta que hay que respaldar y armamos un paquete por cada una.
for ruta_origen in "${FUENTES_RESPALDO[@]}"; do
    nombre_origen=$(basename "$ruta_origen")
    # Limpiamos el nombre con sed para que no tenga caracteres raros en el archivo tar
    nombre_origen=$(echo "$nombre_origen" | sed 's/[^a-zA-Z0-9._-]/_/g')

    if [[ ! -d "$ruta_origen" ]]; then
        registrar_advertencia "Se omite $(ruta_corta "$ruta_origen") porque no existe o no es una carpeta."
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$fecha_ejecucion" "$etiqueta_lote" "$ruta_origen" "-" "0" "0" "-" "OMITIDO" >> "$ARCHIVO_HISTORIAL_RESPALDOS"
        cantidad_omitidas=$((cantidad_omitidas + 1))
        continue
    fi

    ruta_respaldo="$carpeta_lote/${etiqueta_lote}_${nombre_origen}_${id_actual}.tar.gz"
    tar -czf "$ruta_respaldo" -C "$(dirname "$ruta_origen")" "$nombre_origen"

    archivos_encontrados=$(find "$ruta_origen" -type f | wc -l | tr -d '[:space:]')
    peso_respaldo=$(wc -c < "$ruta_respaldo" | tr -d '[:space:]')
    hash_respaldo=$(calcular_hash "$ruta_respaldo")

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$ruta_origen" "$ruta_respaldo" "$archivos_encontrados" "$peso_respaldo" "$hash_respaldo" "$etiqueta_lote" "OK" >> "$archivo_manifiesto"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$fecha_ejecucion" "$etiqueta_lote" "$ruta_origen" "$ruta_respaldo" "$archivos_encontrados" "$peso_respaldo" "$hash_respaldo" "OK" >> "$ARCHIVO_HISTORIAL_RESPALDOS"

    cantidad_paquetes=$((cantidad_paquetes + 1))
    cantidad_archivos=$((cantidad_archivos + archivos_encontrados))
    bytes_totales=$((bytes_totales + peso_respaldo))
    cantidad_ok=$((cantidad_ok + 1))
done

archivo_envio=$(simular_envio_reporte "reporte-respaldo-$id_actual" "$CORREO_DESTINO_RESPALDO" "$archivo_reporte" "$CANAL_ENVIO_RESPALDO")

# Armamos el reporte con el resumen de todo lo que se respaldo.
{
    imprimir_separador
    echo "COPIAS DE SEGURIDAD DIARIAS - REPORTE DE EJECUCION"
    imprimir_separador
    imprimir_dato "Proyecto" "$NOMBRE_PROYECTO"
    imprimir_dato "Fecha de ejecucion" "$fecha_ejecucion"
    imprimir_dato "Etiqueta del lote" "$etiqueta_lote"
    imprimir_dato "Carpeta del lote" "$(ruta_corta "$carpeta_lote")"
    imprimir_dato "Fuentes evaluadas" "${#FUENTES_RESPALDO[@]}"
    imprimir_dato "Paquetes generados" "$cantidad_paquetes"
    imprimir_dato "Archivos respaldados" "$cantidad_archivos"
    imprimir_dato "Tamano total" "$bytes_totales bytes"
    imprimir_dato "Fuentes correctas" "$cantidad_ok"
    imprimir_dato "Fuentes omitidas" "$cantidad_omitidas"
    imprimir_dato "Registro de envio" "$(ruta_corta "$archivo_envio")"
    echo
    echo "Detalle por carpeta:"
    if [[ -s "$archivo_manifiesto" ]]; then
        awk -F'\t' -v raiz="$RAIZ_PROYECTO/" '{ gsub(raiz, "", $1); gsub(raiz, "", $2); printf " - %s => %s | archivos=%s | bytes=%s\n", $1, $2, $3, $4 }' "$archivo_manifiesto"
    else
        echo " - No se generaron respaldos en esta ejecucion."
    fi
} > "$archivo_reporte"

cp "$archivo_reporte" "$archivo_reporte_reciente"

# Para que no se acumulen demasiados respaldos, eliminamos los mas viejos.
shopt -s nullglob
lotes_guardados=("$CARPETA_RESPALDOS"/lote_respaldo_*)
if (( ${#lotes_guardados[@]} > maximo_retencion )); then
    mapfile -t lotes_ordenados < <(printf '%s\n' "${lotes_guardados[@]}" | sort -r)
    for lote_antiguo in "${lotes_ordenados[@]:maximo_retencion}"; do
        rm -rf "$lote_antiguo"
    done
fi
shopt -u nullglob

cat "$archivo_reporte"
registrar_info "Modulo de copias de seguridad finalizado."
