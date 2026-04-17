#!/usr/bin/env bash
# ejecutar_todo.sh
# Orquesta todos los modulos de punta a punta. Es el script que usamos
# para validar el proyecto antes de sustentar.
#
# Pasos: preparar -> respaldo -> monitoreo -> roles -> reporte diario
#         -> reporte maestro.

set -euo pipefail
IFS=$'\n\t'

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/biblioteca/comun.sh"

archivo_config="$HERE/configuracion/proyecto_final.conf"
escenario="mixto"
alcance_roles="laboratorio"
etiqueta="integral"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --escenario)     escenario=$2; shift 2 ;;
        --alcance-roles) alcance_roles=$2; shift 2 ;;
        --etiqueta)      etiqueta=$2; shift 2 ;;
        --config)        archivo_config=$2; shift 2 ;;
        --help|-h)
            cat <<'EOF'
uso: ejecutar_todo.sh [--escenario base|critico|mixto]
                      [--alcance-roles laboratorio|sistema|auto]
                      [--etiqueta nombre] [--config ruta]
EOF
            exit 0
            ;;
        *) echo "parametro no reconocido: $1" >&2; exit 1 ;;
    esac
done

paso() {
    local num=$1; shift
    echo
    imprimir_separador
    echo "  PASO $num/6: $*"
    imprimir_separador
}

echo
imprimir_separador
echo "  PROYECTO FINAL DE AUTOMATIZACION EN SHELL"
echo "  Escenario: $escenario | Roles: $alcance_roles | Etiqueta: $etiqueta"
imprimir_separador

paso 1 "preparando entorno de prueba"
bash "$HERE/preparar_entorno_prueba.sh" --config "$archivo_config" --escenario "$escenario"

paso 2 "copias de seguridad"
bash "$HERE/copias_seguridad.sh" --config "$archivo_config" --etiqueta "$etiqueta"

paso 3 "monitoreo de logs"
# El monitoreo devuelve exit 2 si encuentra criticas; eso NO es un error
# del script sino una senal para otros procesos. Lo capturamos a proposito.
codigo_monitoreo=0
bash "$HERE/monitorear_logs.sh" --config "$archivo_config" --modo completo --lineas 500 \
    || codigo_monitoreo=$?
if (( codigo_monitoreo == 2 )); then
    registrar_advertencia "monitoreo reporto alertas criticas (esperado en escenarios critico/mixto)"
elif (( codigo_monitoreo != 0 )); then
    terminar_con_error "monitoreo fallo con codigo $codigo_monitoreo"
fi

paso 4 "gestion de usuarios y roles"
bash "$HERE/gestionar_roles.sh" --config "$archivo_config" --alcance "$alcance_roles" --aplicar

paso 5 "reporte diario de monitoreo"
bash "$HERE/generar_reporte_logs.sh" --config "$archivo_config" --con-respaldo

paso 6 "reporte maestro"
bash "$HERE/generar_reporte_maestro.sh" --config "$archivo_config" --con-bundle

echo
imprimir_separador
echo "  PROYECTO COMPLETADO - revisa la carpeta 'reportes/'"
imprimir_separador
