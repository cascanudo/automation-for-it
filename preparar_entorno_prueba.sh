#!/usr/bin/env bash
# preparar_entorno_prueba.sh -- deja el proyecto listo para correr la demo
# desde cero: limpia reportes viejos, recrea recursos y siembra logs.

set -euo pipefail
IFS=$'\n\t'

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/biblioteca/comun.sh"

activar_trampa_errores

ayuda() {
    cat <<'EOF'
uso: preparar_entorno_prueba.sh [--config ruta] [--escenario base|critico|mixto]
EOF
}

archivo_config="$ARCHIVO_CONFIG_PREDETERMINADO"
escenario="mixto"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)    archivo_config=$2; shift 2 ;;
        --escenario) escenario=$2; shift 2 ;;
        --help|-h)   ayuda; exit 0 ;;
        *) terminar_con_error "parametro no reconocido: $1" ;;
    esac
done

cargar_configuracion "$archivo_config"
inicializar_entorno

# recursos de respaldo (carpetas de ejemplo que se comprimen despues)
asegurar_directorio "$RAIZ_PROYECTO/recursos_prueba/fuentes_respaldo/configuracion_aplicacion"
asegurar_directorio "$RAIZ_PROYECTO/recursos_prueba/fuentes_respaldo/datos_aplicacion"
asegurar_directorio "$RAIZ_PROYECTO/recursos_prueba/fuentes_respaldo/base_reportes"

# limpiamos lo que haya quedado de corridas anteriores
find "$CARPETA_REPORTES"    -type f     ! -name '.gitkeep' -delete 2>/dev/null || true
find "$CARPETA_RESPALDOS"   -mindepth 1 ! -name '.gitkeep' -exec rm -rf {} + 2>/dev/null || true
find "$CARPETA_TEMPORAL"    -type f     ! -name '.gitkeep' -delete 2>/dev/null || true
find "$CARPETA_BUZON"       -type f     ! -name '.gitkeep' -delete 2>/dev/null || true
find "$CARPETA_CHECKPOINTS" -type f     ! -name '.gitkeep' -delete 2>/dev/null || true
find "$CARPETA_LABORATORIO" -mindepth 1 ! -name '.gitkeep' -exec rm -rf {} + 2>/dev/null || true

: > "$ARCHIVO_HISTORIAL_ALERTAS"
: > "$ARCHIVO_HISTORIAL_RESPALDOS"
: > "$ARCHIVO_HISTORIAL_USUARIOS"

# datos de ejemplo: van al repo asi el docente ve que hay algo que respaldar
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

# NOTA: antes poniamos marca_tiempo aca pero hacia que git siempre viera
# inventario.txt como modificado. Dejamos un valor fijo.
cat > "$RAIZ_PROYECTO/recursos_prueba/fuentes_respaldo/datos_aplicacion/inventario.txt" <<'EOF'
nodos_api=3
cola_trabajo=14
ultima_sincronizacion=dato-fijo-para-demo
EOF

cat > "$RAIZ_PROYECTO/recursos_prueba/fuentes_respaldo/base_reportes/estado_servicios.txt" <<EOF
Servicio web: OK
Base de datos: OK
Replica: EN ESPERA
EOF

bash "$HERE/simular_logs.sh" --config "$archivo_config" --escenario "$escenario" --reset

registrar_info "entorno listo con escenario=$escenario"
imprimir_dato "Escenario cargado"     "$escenario"
imprimir_dato "Carpeta de reportes"   "$(ruta_corta "$CARPETA_REPORTES")"
imprimir_dato "Carpeta de respaldos"  "$(ruta_corta "$CARPETA_RESPALDOS")"
imprimir_dato "Carpeta de laboratorio" "$(ruta_corta "$CARPETA_LABORATORIO")"
