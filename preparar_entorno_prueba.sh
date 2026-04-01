#!/usr/bin/env bash
# ============================================================
# preparar_entorno_prueba.sh
# Limpia y prepara el entorno antes de cada demostracion
# Proyecto Final - Shell Scripting - IDAT 2026-I
# Grupo: Santos, Juarez, Chavez, Taboada
# ============================================================
# Borra los archivos que quedaron de corridas anteriores,
# siembra datos de ejemplo y carga el escenario de logs.
# Asi cada vez que probamos el proyecto partimos de cero.

set -euo pipefail
IFS=$'\n\t'

CARPETA_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$CARPETA_SCRIPT/biblioteca/comun.sh"

mostrar_ayuda() {
    cat <<'EOF'
Uso:
  ./preparar_entorno_prueba.sh [--config ruta] [--escenario base|critico|mixto]
EOF
}

archivo_config="$ARCHIVO_CONFIG_PREDETERMINADO"
escenario="mixto"

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

asegurar_directorio "$RAIZ_PROYECTO/recursos_prueba/fuentes_respaldo/configuracion_aplicacion"
asegurar_directorio "$RAIZ_PROYECTO/recursos_prueba/fuentes_respaldo/datos_aplicacion"
asegurar_directorio "$RAIZ_PROYECTO/recursos_prueba/fuentes_respaldo/base_reportes"

find "$CARPETA_REPORTES" -type f ! -name '.gitkeep' -delete 2>/dev/null || true
find "$CARPETA_RESPALDOS" -mindepth 1 ! -name '.gitkeep' -exec rm -rf {} + 2>/dev/null || true
find "$CARPETA_TEMPORAL" -type f ! -name '.gitkeep' -delete 2>/dev/null || true
find "$CARPETA_BUZON" -type f ! -name '.gitkeep' -delete 2>/dev/null || true
find "$CARPETA_CHECKPOINTS" -type f ! -name '.gitkeep' -delete 2>/dev/null || true
find "$CARPETA_LABORATORIO" -mindepth 1 ! -name '.gitkeep' -exec rm -rf {} + 2>/dev/null || true

: > "$ARCHIVO_HISTORIAL_ALERTAS"
: > "$ARCHIVO_HISTORIAL_RESPALDOS"
: > "$ARCHIVO_HISTORIAL_USUARIOS"

cat > "$RAIZ_PROYECTO/recursos_prueba/fuentes_respaldo/configuracion_aplicacion/app.env" <<EOF
APP_NOMBRE=proyecto_final_shell
APP_ENTORNO=prueba
MODO_MANTENIMIENTO=false
EOF

cat > "$RAIZ_PROYECTO/recursos_prueba/fuentes_respaldo/configuracion_aplicacion/nginx.conf" <<EOF
server_name prueba.proyecto-final.local;
listen 8080;
proxy_read_timeout 30;
EOF

cat > "$RAIZ_PROYECTO/recursos_prueba/fuentes_respaldo/datos_aplicacion/pedidos.csv" <<EOF
pedido_id,cliente,total,estado
1001,Acme,120.50,pagado
1002,Globex,89.90,pendiente
EOF

cat > "$RAIZ_PROYECTO/recursos_prueba/fuentes_respaldo/datos_aplicacion/inventario.txt" <<EOF
nodos_api=3
cola_trabajo=14
ultima_sincronizacion=$(marca_tiempo)
EOF

cat > "$RAIZ_PROYECTO/recursos_prueba/fuentes_respaldo/base_reportes/estado_servicios.txt" <<EOF
Servicio web: OK
Base de datos: OK
Replica: EN ESPERA
EOF

bash "$CARPETA_SCRIPT/simular_logs.sh" --config "$archivo_config" --escenario "$escenario" --reset
registrar_info "Entorno de prueba preparado con el escenario $escenario."
