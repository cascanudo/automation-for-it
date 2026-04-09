#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# comun.sh - Biblioteca comun del proyecto
# Funciones compartidas, validaciones y rutas base
# Proyecto Final - Shell Scripting - IDAT 2026-I
# Grupo: Santos, Juarez, Chavez, Taboada
# ============================================================

RAIZ_PROYECTO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVO_CONFIG_PREDETERMINADO="$RAIZ_PROYECTO/configuracion/proyecto_final.conf"

# --- Funciones de registro (logs internos del proyecto) ---

marca_tiempo() {
    date "+%Y-%m-%d %H:%M:%S"
}

registrar_info() {
    printf '[%s] [INFO] %s\n' "$(marca_tiempo)" "$*"
}

registrar_advertencia() {
    printf '[%s] [ADVERTENCIA] %s\n' "$(marca_tiempo)" "$*" >&2
}

registrar_error() {
    printf '[%s] [ERROR] %s\n' "$(marca_tiempo)" "$*" >&2
}

terminar_con_error() {
    registrar_error "$*"
    exit 1
}

# --- Funciones de validacion y comprobacion ---

asegurar_directorio() {
    mkdir -p "$1"
}

exigir_archivo_lectura() {
    local archivo=$1
    [[ -f "$archivo" ]] || terminar_con_error "No existe el archivo requerido: $archivo"
    [[ -r "$archivo" ]] || terminar_con_error "No se puede leer el archivo requerido: $archivo"
}

exigir_comando() {
    local nombre_comando=$1
    command -v "$nombre_comando" >/dev/null 2>&1 || terminar_con_error "No se encontro el comando requerido: $nombre_comando"
}

comando_disponible() {
    command -v "$1" >/dev/null 2>&1
}

# --- Funciones auxiliares de texto y formato ---

nombre_seguro() {
    local valor=$1
    valor=${valor//\//_}
    valor=${valor//\\/_}
    valor=${valor// /_}
    valor=${valor//:/_}
    printf '%s' "$valor"
}

# Limpia una ruta quitando barras repetidas o puntos innecesarios.
normalizar_ruta() {
    local ruta=$1
    ruta=$(echo "$ruta" | sed 's|/\+|/|g; s|/\./|/|g; s|/$||')
    printf '%s' "$ruta"
}

# Muestra la ruta relativa al proyecto para que la salida sea mas corta y legible.
ruta_corta() {
    local ruta=$1
    echo "$ruta" | sed "s|$RAIZ_PROYECTO/||g; s|$RAIZ_PROYECTO||g"
}

# Imprime un banner grande para separar visualmente cada modulo en la salida.
imprimir_banner() {
    local titulo=$1
    echo ""
    echo "************************************************************"
    echo "  $titulo"
    echo "************************************************************"
    echo ""
}

id_ejecucion() {
    date "+%Y%m%d_%H%M%S"
}

fecha_actual() {
    date "+%Y-%m-%d"
}

contar_lineas() {
    local archivo=$1
    if [[ -f "$archivo" ]]; then
        wc -l < "$archivo" | tr -d '[:space:]'
    else
        printf '0'
    fi
}

imprimir_separador() {
    printf '%s\n' "============================================================"
}

imprimir_dato() {
    printf '%-28s %s\n' "$1" "$2"
}

es_verdadero() {
    local valor=${1,,}
    [[ "$valor" == "1" || "$valor" == "true" || "$valor" == "yes" || "$valor" == "si" ]]
}

ejecutando_como_root() {
    [[ "$(id -u)" -eq 0 ]]
}

calcular_hash() {
    local archivo=$1

    if comando_disponible sha256sum; then
        sha256sum "$archivo" | awk '{print $1}'
    elif comando_disponible shasum; then
        shasum -a 256 "$archivo" | awk '{print $1}'
    else
        cksum "$archivo" | awk '{print $1 "-" $2}'
    fi
}

simular_envio_reporte() {
    local asunto=$1
    local destinatario=$2
    local archivo_reporte=$3
    local canal=${4:-archivo}
    local archivo_salida

    asegurar_directorio "$CARPETA_BUZON"
    archivo_salida="$CARPETA_BUZON/envio_$(nombre_seguro "$asunto")_$(id_ejecucion).txt"

    {
        imprimir_separador
        echo "REGISTRO DE ENVIO DE REPORTE"
        imprimir_separador
        imprimir_dato "Fecha" "$(marca_tiempo)"
        imprimir_dato "Canal" "$canal"
        imprimir_dato "Destinatario" "$destinatario"
        imprimir_dato "Asunto" "$asunto"
        imprimir_dato "Adjunto" "$archivo_reporte"
    } > "$archivo_salida"

    printf '%s\n' "$archivo_salida"
}

# --- Carga de configuracion y arranque del entorno ---

cargar_configuracion() {
    local archivo_config=${1:-$ARCHIVO_CONFIG_PREDETERMINADO}

    FUENTES_LOG=()
    FUENTES_RESPALDO=()

    exigir_archivo_lectura "$archivo_config"
    # shellcheck disable=SC1090
    source "$archivo_config"

    : "${NOMBRE_PROYECTO:=Proyecto Final De Automatizacion En Shell}"
    : "${NOMBRE_ENTORNO:=laboratorio-prueba}"
    : "${CARPETA_REPORTES:=$RAIZ_PROYECTO/reportes}"
    : "${CARPETA_ESTADO:=$RAIZ_PROYECTO/estado}"
    : "${CARPETA_RESPALDOS:=$RAIZ_PROYECTO/respaldos}"
    : "${CARPETA_TEMPORAL:=$RAIZ_PROYECTO/temporal}"
    : "${CARPETA_CHECKPOINTS:=$CARPETA_ESTADO/checkpoints}"
    : "${CARPETA_BUZON:=$RAIZ_PROYECTO/buzon}"
    : "${CARPETA_LABORATORIO:=$RAIZ_PROYECTO/laboratorio}"
    : "${ARCHIVO_PATRONES:=$RAIZ_PROYECTO/configuracion/patrones.conf}"
    : "${ARCHIVO_ROLES:=$RAIZ_PROYECTO/configuracion/roles.tsv}"
    : "${ARCHIVO_USUARIOS:=$RAIZ_PROYECTO/configuracion/usuarios.tsv}"
    : "${ARCHIVO_HISTORIAL_ALERTAS:=$CARPETA_ESTADO/alertas_historial.tsv}"
    : "${ARCHIVO_HISTORIAL_RESPALDOS:=$CARPETA_ESTADO/respaldos_historial.tsv}"
    : "${ARCHIVO_HISTORIAL_USUARIOS:=$CARPETA_ESTADO/usuarios_historial.tsv}"
    : "${MODO_ESCANEO_PREDETERMINADO:=incremental}"
    : "${LINEAS_REVISION_PREDETERMINADAS:=300}"
    : "${UMBRAL_SALIDA_CRITICA:=1}"
    : "${GENERAR_RESPALDO_REPORTE:=true}"
    : "${MAXIMO_LOTES_RESPALDO:=5}"
    : "${CORREO_DESTINO_RESPALDO:=operaciones@empresa.local}"
    : "${CANAL_ENVIO_RESPALDO:=archivo-local}"
    : "${ALCANCE_ROLES_PREDETERMINADO:=laboratorio}"
    : "${RUTA_BASE_ROLES_SISTEMA:=/srv/proyecto_final_automatizacion_shell}"
    : "${CARPETA_ROLES_LAB:=$CARPETA_LABORATORIO/roles}"
    : "${CARPETA_USUARIOS_LAB:=$CARPETA_LABORATORIO/usuarios}"
    : "${ETIQUETA_CRON:=proyecto-final-shell}"
}

inicializar_entorno() {
    asegurar_directorio "$CARPETA_REPORTES"
    asegurar_directorio "$CARPETA_ESTADO"
    asegurar_directorio "$CARPETA_RESPALDOS"
    asegurar_directorio "$CARPETA_TEMPORAL"
    asegurar_directorio "$CARPETA_CHECKPOINTS"
    asegurar_directorio "$CARPETA_BUZON"
    asegurar_directorio "$CARPETA_LABORATORIO"
    asegurar_directorio "$CARPETA_ROLES_LAB"
    asegurar_directorio "$CARPETA_USUARIOS_LAB"

    touch "$ARCHIVO_HISTORIAL_ALERTAS"
    touch "$ARCHIVO_HISTORIAL_RESPALDOS"
    touch "$ARCHIVO_HISTORIAL_USUARIOS"
}

archivo_checkpoint() {
    local ruta_fuente=$1
    printf '%s/%s.estado\n' "$CARPETA_CHECKPOINTS" "$(nombre_seguro "$ruta_fuente")"
}

resolver_alcance_roles() {
    local alcance_solicitado=${1:-$ALCANCE_ROLES_PREDETERMINADO}

    if [[ "$alcance_solicitado" == "auto" ]]; then
        if ejecutando_como_root && comando_disponible useradd && comando_disponible groupadd; then
            printf 'sistema\n'
        else
            printf 'laboratorio\n'
        fi
    else
        printf '%s\n' "$alcance_solicitado"
    fi
}
