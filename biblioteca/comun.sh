#!/usr/bin/env bash
# biblioteca/comun.sh
# Funciones compartidas, rutas base y carga de configuracion.

set -euo pipefail

RAIZ_PROYECTO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVO_CONFIG_PREDETERMINADO="$RAIZ_PROYECTO/configuracion/proyecto_final.conf"

# -------- logging --------

marca_tiempo() { date "+%Y-%m-%d %H:%M:%S"; }

registrar_info()        { printf '[%s] [INFO] %s\n' "$(marca_tiempo)" "$*"; }
registrar_advertencia() { printf '[%s] [WARN] %s\n' "$(marca_tiempo)" "$*" >&2; }
registrar_error()       { printf '[%s] [ERROR] %s\n' "$(marca_tiempo)" "$*" >&2; }

terminar_con_error() {
    registrar_error "$*"
    exit 1
}

# Trampa de errores opcional: cada script principal puede activarla con
# activar_trampa_errores para que un fallo inesperado muestre el contexto.
activar_trampa_errores() {
    trap 'registrar_error "fallo en ${BASH_SOURCE[1]:-script}:${LINENO} (codigo $?)"' ERR
}

# -------- validaciones --------

asegurar_directorio() { mkdir -p "$1"; }

exigir_archivo_lectura() {
    local f=$1
    [[ -f "$f" ]] || terminar_con_error "no existe el archivo: $f"
    [[ -r "$f" ]] || terminar_con_error "no se puede leer: $f"
}

exigir_comando() {
    command -v "$1" >/dev/null 2>&1 || terminar_con_error "falta el comando: $1"
}

comando_disponible() { command -v "$1" >/dev/null 2>&1; }

# -------- auxiliares de texto --------

# Reemplaza caracteres problematicos por guion bajo usando expansion pura de bash.
nombre_seguro() {
    local v=$1
    v=${v//\//_}
    v=${v//\\/_}
    v=${v// /_}
    v=${v//:/_}
    printf '%s' "$v"
}

# Muestra una ruta relativa a la raiz del proyecto. Si no empieza con la raiz
# la devuelve tal cual.
ruta_corta() {
    local r=$1
    if [[ "$r" == "$RAIZ_PROYECTO"* ]]; then
        printf '%s' "${r#$RAIZ_PROYECTO/}"
    else
        printf '%s' "$r"
    fi
}

id_ejecucion() { date "+%Y%m%d_%H%M%S"; }
fecha_actual() { date "+%Y-%m-%d"; }

contar_lineas() {
    local f=$1
    if [[ -f "$f" ]]; then
        wc -l < "$f" | tr -d '[:space:]'
    else
        printf '0'
    fi
}

imprimir_separador() {
    printf -- '------------------------------------------------------------\n'
}

imprimir_dato() { printf '%-28s %s\n' "$1" "$2"; }

es_si() {
    local v=${1,,}
    [[ "$v" == "1" || "$v" == "true" || "$v" == "yes" || "$v" == "si" ]]
}

# Compatibilidad con la version anterior: algunos scripts todavia usan es_verdadero.
es_verdadero() { es_si "$@"; }

ejecutando_como_root() { [[ "$(id -u)" -eq 0 ]]; }

calcular_hash() {
    local f=$1
    if comando_disponible sha256sum; then
        sha256sum "$f" | awk '{print $1}'
    elif comando_disponible shasum; then
        shasum -a 256 "$f" | awk '{print $1}'
    else
        # Ultimo recurso: cksum no es criptografico pero al menos detecta corrupcion.
        cksum "$f" | awk '{print $1 "-" $2}'
    fi
}

# Escribe un registro del envio del reporte en el buzon. No envia correo real,
# deja evidencia del intento (simulacion aprobada por el docente en la sesion 10).
simular_envio_reporte() {
    local asunto=$1
    local destinatario=$2
    local archivo_reporte=$3
    local canal=${4:-archivo}
    local salida

    asegurar_directorio "$CARPETA_BUZON"
    salida="$CARPETA_BUZON/envio_$(nombre_seguro "$asunto")_$(id_ejecucion).txt"

    {
        imprimir_separador
        echo "REGISTRO DE ENVIO DE REPORTE"
        imprimir_separador
        imprimir_dato "Fecha" "$(marca_tiempo)"
        imprimir_dato "Canal" "$canal"
        imprimir_dato "Destinatario" "$destinatario"
        imprimir_dato "Asunto" "$asunto"
        imprimir_dato "Adjunto" "$archivo_reporte"
    } > "$salida"

    printf '%s\n' "$salida"
}

# -------- configuracion --------

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
    local d
    for d in "$CARPETA_REPORTES" "$CARPETA_ESTADO" "$CARPETA_RESPALDOS" \
             "$CARPETA_TEMPORAL" "$CARPETA_CHECKPOINTS" "$CARPETA_BUZON" \
             "$CARPETA_LABORATORIO" "$CARPETA_ROLES_LAB" "$CARPETA_USUARIOS_LAB"; do
        asegurar_directorio "$d"
    done

    # Validacion util cuando alguien cambia el proyecto de ubicacion y deja
    # CARPETA_REPORTES apuntando a una ruta que no es escribible.
    [[ -w "$CARPETA_REPORTES" ]] || terminar_con_error "la carpeta de reportes no es escribible: $CARPETA_REPORTES"

    touch "$ARCHIVO_HISTORIAL_ALERTAS" \
          "$ARCHIVO_HISTORIAL_RESPALDOS" \
          "$ARCHIVO_HISTORIAL_USUARIOS"
}

archivo_checkpoint() {
    printf '%s/%s.estado\n' "$CARPETA_CHECKPOINTS" "$(nombre_seguro "$1")"
}

# Decide entre laboratorio y sistema. "auto" usa sistema solo si corresponde.
resolver_alcance_roles() {
    local solicitado=${1:-$ALCANCE_ROLES_PREDETERMINADO}

    if [[ "$solicitado" == "auto" ]]; then
        if ejecutando_como_root && comando_disponible useradd && comando_disponible groupadd; then
            printf 'sistema\n'
        else
            printf 'laboratorio\n'
        fi
    else
        printf '%s\n' "$solicitado"
    fi
}

# Limpia CRLF de archivos que vienen de Windows. Lo llamamos antes de leer
# los TSV porque ya nos paso mas de una vez que Git Bash los guarde con \r.
sanear_crlf() {
    local f=$1
    [[ -f "$f" && -w "$f" ]] || return 0
    if grep -q $'\r' "$f" 2>/dev/null; then
        sed -i 's/\r$//' "$f"
    fi
}
