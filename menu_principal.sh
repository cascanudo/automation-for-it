#!/usr/bin/env bash
# menu_principal.sh -- menu interactivo para la sustentacion.

set -euo pipefail
IFS=$'\n\t'

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
archivo_config="$HERE/configuracion/proyecto_final.conf"

pausar() {
    echo
    read -r -p "Enter para continuar... " _
}

ver_reportes() {
    local f
    for f in "$HERE/reportes/ultimo_reporte_respaldos.txt" \
             "$HERE/reportes/ultimo_resumen_monitoreo.txt" \
             "$HERE/reportes/ultimo_reporte_logs.txt" \
             "$HERE/reportes/ultimo_reporte_usuarios.txt" \
             "$HERE/reportes/ultimo_reporte_maestro.txt"; do
        if [[ -f "$f" ]]; then
            echo
            echo ">>> $f"
            cat "$f"
        fi
    done
}

while true; do
    cat <<'MENU'

============================================================
PROYECTO FINAL DE AUTOMATIZACION EN SHELL
============================================================
 1) Preparar entorno de prueba
 2) Ejecutar copias de seguridad
 3) Ejecutar monitoreo de logs
 4) Gestionar usuarios y roles
 5) Generar reporte diario de logs
 6) Generar reporte maestro
 7) Ver automatizacion cron recomendada
 8) Ejecutar proyecto completo
 9) Ver reportes recientes
10) Salir
============================================================
MENU
    read -r -p "Elige una opcion: " op

    case "$op" in
        1)  bash "$HERE/preparar_entorno_prueba.sh" --config "$archivo_config" --escenario mixto ; pausar ;;
        2)  bash "$HERE/copias_seguridad.sh"        --config "$archivo_config" --etiqueta menu   ; pausar ;;
        3)  bash "$HERE/monitorear_logs.sh"         --config "$archivo_config" --modo completo --lineas 500 || true ; pausar ;;
        4)  bash "$HERE/gestionar_roles.sh"         --config "$archivo_config" --alcance laboratorio --aplicar ; pausar ;;
        5)  bash "$HERE/generar_reporte_logs.sh"    --config "$archivo_config" --con-respaldo    ; pausar ;;
        6)  bash "$HERE/generar_reporte_maestro.sh" --config "$archivo_config" --con-bundle      ; pausar ;;
        7)  bash "$HERE/programar_tareas.sh" ver    --config "$archivo_config" ; pausar ;;
        8)  bash "$HERE/ejecutar_todo.sh" --config "$archivo_config" --escenario mixto --alcance-roles laboratorio --etiqueta final ; pausar ;;
        9)  ver_reportes ; pausar ;;
        10) echo "listo."; break ;;
        *)  echo "opcion no valida" ;;
    esac
done
