#!/usr/bin/env bash
# ============================================================
# simular_logs.sh
# Genera logs de prueba con distintos escenarios
# Proyecto Final - Shell Scripting - IDAT 2026-I
# Grupo: Santos, Juarez, Chavez, Taboada
# ============================================================
# Crea eventos simulados en los archivos de log para que
# podamos probar el monitoreo sin depender de logs reales.
# Hay tres escenarios: base (todo normal), critico (con fallas)
# y mixto (mezcla de ambos, el que usamos en la sustentacion).

set -euo pipefail
IFS=$'\n\t'

CARPETA_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$CARPETA_SCRIPT/biblioteca/comun.sh"

mostrar_ayuda() {
    cat <<'EOF'
Uso:
  ./simular_logs.sh [--config ruta] [--escenario base|critico|mixto] [--reset]

Opciones:
  --config     Archivo de configuracion del proyecto.
  --escenario  Define el tipo de eventos que se generaran.
  --reset      Limpia los logs y el historial antes de sembrar datos.
  --help       Muestra esta ayuda.
EOF
}

archivo_config="$ARCHIVO_CONFIG_PREDETERMINADO"
escenario="mixto"
reiniciar=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)
            archivo_config=$2
            shift 2
            ;;
        --escenario)
            escenario=$2
            shift 2
            ;;
        --reset)
            reiniciar=true
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

archivo_app="$RAIZ_PROYECTO/logs_prueba/app.log"
archivo_auth="$RAIZ_PROYECTO/logs_prueba/auth.log"

# Dejamos la carpeta de logs preparada por si el usuario parte de un repo recien clonado.
asegurar_directorio "$RAIZ_PROYECTO/logs_prueba"

if es_verdadero "$reiniciar"; then
    : > "$archivo_app"
    : > "$archivo_auth"
    rm -f "$CARPETA_CHECKPOINTS"/*.estado 2>/dev/null || true
    : > "$ARCHIVO_HISTORIAL_ALERTAS"
fi

agregar_linea() {
    local archivo=$1
    local mensaje=$2
    printf '%s %s\n' "$(marca_tiempo)" "$mensaje" >> "$archivo"
}

case "$escenario" in
    base)
        agregar_linea "$archivo_app" "INFO aplicacion iniciada sin novedades"
        agregar_linea "$archivo_app" "INFO latido del servicio correcto"
        agregar_linea "$archivo_auth" "INFO acceso del usuario analista exitoso"
        ;;
    critico)
        agregar_linea "$archivo_app" "ERROR database unavailable on primary cluster"
        agregar_linea "$archivo_app" "WARN api timeout calling billing service"
        agregar_linea "$archivo_auth" "Failed password for admin from 10.10.5.20 port 22"
        agregar_linea "$archivo_auth" "root login denied from 10.10.5.20"
        ;;
    mixto)
        agregar_linea "$archivo_app" "INFO despliegue iniciado correctamente"
        agregar_linea "$archivo_app" "WARN cache timeout reaching redis node"
        agregar_linea "$archivo_app" "ERROR database unavailable during checkout"
        agregar_linea "$archivo_app" "deprecated config key legacy_mode=true"
        agregar_linea "$archivo_auth" "INFO acceso de cuenta de servicio correcto"
        agregar_linea "$archivo_auth" "invalid user oracle from 172.16.0.8"
        agregar_linea "$archivo_auth" "Failed password for root from 172.16.0.9 port 22"
        ;;
    *)
        terminar_con_error "Escenario no soportado: $escenario"
        ;;
esac

registrar_info "Escenario cargado: $escenario"
imprimir_dato "Log de aplicacion" "$archivo_app"
imprimir_dato "Log de autenticacion" "$archivo_auth"
