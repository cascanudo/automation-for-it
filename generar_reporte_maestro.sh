#!/usr/bin/env bash
# ============================================================
# generar_reporte_maestro.sh
# Reporte maestro que consolida los tres modulos del proyecto
# Proyecto Final - Shell Scripting - IDAT 2026-I
# Grupo: Santos, Juarez, Chavez, Taboada
# ============================================================
# Este script junta la evidencia de respaldos, monitoreo y
# gestion de usuarios en un solo reporte. Es el que presentamos
# al final para demostrar que todo funciono correctamente.

set -euo pipefail
IFS=$'\n\t'

CARPETA_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$CARPETA_SCRIPT/biblioteca/comun.sh"

mostrar_ayuda() {
    cat <<'EOF'
Uso:
  ./generar_reporte_maestro.sh [--config ruta] [--fecha YYYY-MM-DD] [--con-bundle]

Opciones:
  --config      Archivo de configuracion del proyecto.
  --fecha       Fecha a consolidar.
  --con-bundle  Empaqueta los reportes mas recientes en un solo archivo.
  --help        Muestra esta ayuda.
EOF
}

archivo_config="$ARCHIVO_CONFIG_PREDETERMINADO"
fecha_objetivo=""
crear_bundle=false

# Juntamos toda la informacion del proyecto para cerrar con una evidencia clara y completa.
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
        --con-bundle)
            crear_bundle=true
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

# Para este punto los modulos ya corrieron, asi que solo necesitamos las herramientas de filtrado.
exigir_comando awk
exigir_comando grep
exigir_comando tar

fecha_objetivo=${fecha_objetivo:-$(fecha_actual)}
archivo_maestro="$CARPETA_REPORTES/reporte_maestro_${fecha_objetivo}.txt"
archivo_maestro_reciente="$CARPETA_REPORTES/ultimo_reporte_maestro.txt"
archivo_logs_dia="$CARPETA_TEMPORAL/maestro_logs_${fecha_objetivo}.tsv"
archivo_respaldos_dia="$CARPETA_TEMPORAL/maestro_respaldos_${fecha_objetivo}.tsv"
archivo_usuarios_dia="$CARPETA_TEMPORAL/maestro_usuarios_${fecha_objetivo}.tsv"

reporte_respaldo_reciente="$CARPETA_REPORTES/ultimo_reporte_respaldos.txt"
reporte_logs_reciente="$CARPETA_REPORTES/ultimo_reporte_logs.txt"
reporte_usuarios_reciente="$CARPETA_REPORTES/ultimo_reporte_usuarios.txt"

# Filtramos el historial para quedarnos solo con lo que paso en la fecha que estamos evaluando.
grep "^$fecha_objetivo" "$ARCHIVO_HISTORIAL_ALERTAS" > "$archivo_logs_dia" || true
grep "^$fecha_objetivo" "$ARCHIVO_HISTORIAL_RESPALDOS" > "$archivo_respaldos_dia" || true
grep "^$fecha_objetivo" "$ARCHIVO_HISTORIAL_USUARIOS" > "$archivo_usuarios_dia" || true

# Con estos numeros armamos el resumen ejecutivo que mostramos al sustentar.
cantidad_logs=$(contar_lineas "$archivo_logs_dia")
logs_criticos=$(awk -F'\t' '$2 == "CRITICAL" { n++ } END { print n + 0 }' "$archivo_logs_dia")
cantidad_respaldos=$(contar_lineas "$archivo_respaldos_dia")
respaldos_ok=$(awk -F'\t' '$8 == "OK" { n++ } END { print n + 0 }' "$archivo_respaldos_dia")
cantidad_usuarios=$(contar_lineas "$archivo_usuarios_dia")
usuarios_ok=$(awk -F'\t' '$7 == "OK" { n++ } END { print n + 0 }' "$archivo_usuarios_dia")

{
    imprimir_separador
    echo "REPORTE MAESTRO DEL PROYECTO FINAL"
    imprimir_separador
    imprimir_dato "Proyecto" "$NOMBRE_PROYECTO"
    imprimir_dato "Fecha evaluada" "$fecha_objetivo"
    imprimir_dato "Entorno" "$NOMBRE_ENTORNO"
    echo

    echo "1. Resumen ejecutivo"
    echo " - Respaldos generados: $cantidad_respaldos"
    echo " - Eventos de monitoreo: $cantidad_logs"
    echo " - Eventos criticos: $logs_criticos"
    echo " - Operaciones de usuarios y roles: $cantidad_usuarios"
    echo

    echo "2. Estado de cada modulo"
    if (( cantidad_respaldos > 0 )); then
        echo " - Copias de seguridad: operativas ($respaldos_ok/$cantidad_respaldos registros correctos)."
    else
        echo " - Copias de seguridad: sin ejecucion registrada para la fecha revisada."
    fi
    if (( cantidad_logs > 0 )); then
        echo " - Monitoreo de logs: hubo actividad y ya existe evidencia consolidada."
    else
        echo " - Monitoreo de logs: no se detectaron eventos en la fecha evaluada."
    fi
    if (( cantidad_usuarios > 0 )); then
        echo " - Usuarios y roles: gestion procesada correctamente ($usuarios_ok/$cantidad_usuarios operaciones OK)."
    else
        echo " - Usuarios y roles: sin operaciones registradas ese dia."
    fi
    echo

    echo "3. Evidencia principal"
    [[ -f "$reporte_respaldo_reciente" ]] && echo " - Reporte de respaldos: $(ruta_corta "$reporte_respaldo_reciente")"
    [[ -f "$reporte_logs_reciente" ]] && echo " - Reporte de monitoreo: $(ruta_corta "$reporte_logs_reciente")"
    [[ -f "$reporte_usuarios_reciente" ]] && echo " - Reporte de usuarios: $(ruta_corta "$reporte_usuarios_reciente")"
    echo

    echo "4. Comentario final"
    if (( cantidad_respaldos > 0 && cantidad_logs > 0 && cantidad_usuarios > 0 )); then
echo " - El proyecto evidencia funcionamiento en los tres casos exigidos por el trabajo final."
    else
        echo " - Falta completar evidencia de uno o mas modulos antes de la entrega definitiva."
    fi
    if (( logs_criticos > 0 )); then
        echo " - Antes de sustentar, conviene explicar que los eventos criticos son parte del escenario de prueba controlado."
    fi
} > "$archivo_maestro"

archivo_envio=$(simular_envio_reporte "reporte-maestro-$fecha_objetivo" "$CORREO_DESTINO_RESPALDO" "$archivo_maestro" "$CANAL_ENVIO_RESPALDO")

if es_verdadero "$crear_bundle"; then
    # El paquete final deja una sola evidencia ordenada para entrega o revision posterior.
    archivo_bundle="$CARPETA_RESPALDOS/paquete_maestro_${fecha_objetivo}.tar.gz"
    elementos_bundle=("reportes/$(basename "$archivo_maestro")")
    [[ -f "$reporte_respaldo_reciente" ]] && elementos_bundle+=("reportes/$(basename "$reporte_respaldo_reciente")")
    [[ -f "$reporte_logs_reciente" ]] && elementos_bundle+=("reportes/$(basename "$reporte_logs_reciente")")
    [[ -f "$reporte_usuarios_reciente" ]] && elementos_bundle+=("reportes/$(basename "$reporte_usuarios_reciente")")
    tar -czf "$archivo_bundle" -C "$RAIZ_PROYECTO" "${elementos_bundle[@]}"
    echo >> "$archivo_maestro"
    imprimir_dato "Paquete maestro" "$(ruta_corta "$archivo_bundle")" >> "$archivo_maestro"
fi

echo >> "$archivo_maestro"
imprimir_dato "Registro de envio" "$(ruta_corta "$archivo_envio")" >> "$archivo_maestro"

cp "$archivo_maestro" "$archivo_maestro_reciente"
cat "$archivo_maestro"
registrar_info "Reporte maestro generado correctamente."
