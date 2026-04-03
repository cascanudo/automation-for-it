#!/usr/bin/env bash
# ============================================================
# menu_principal.sh
# Menu interactivo para la sustentacion del proyecto final
# Proyecto Final - Shell Scripting - IDAT 2026-I
# Grupo: Santos, Juarez, Chavez, Taboada
# ============================================================
# Este menu reune los tres modulos del proyecto y permite
# ejecutar cada parte por separado o todo junto. Lo pensamos
# para que sea facil explicar el proyecto en la exposicion.

set -euo pipefail
IFS=$'\n\t'

CARPETA_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
archivo_config="$CARPETA_SCRIPT/configuracion/proyecto_final.conf"

pausar_pantalla() {
    echo
    read -r -p "Presiona Enter para continuar... " _
}

mostrar_reportes_recientes() {
    for archivo_reporte in \
        "$CARPETA_SCRIPT/reportes/ultimo_reporte_respaldos.txt" \
        "$CARPETA_SCRIPT/reportes/ultimo_resumen_monitoreo.txt" \
        "$CARPETA_SCRIPT/reportes/ultimo_reporte_logs.txt" \
        "$CARPETA_SCRIPT/reportes/ultimo_reporte_usuarios.txt" \
        "$CARPETA_SCRIPT/reportes/ultimo_reporte_maestro.txt"; do
        if [[ -f "$archivo_reporte" ]]; then
            echo
            echo "Archivo: $archivo_reporte"
            cat "$archivo_reporte"
        fi
    done
}

while true; do
    echo
    echo "============================================================"
    echo "PROYECTO FINAL DE AUTOMATIZACION EN SHELL"
    echo "============================================================"
    echo "1) Preparar entorno de prueba"
    echo "2) Ejecutar copias de seguridad"
    echo "3) Ejecutar monitoreo de logs"
    echo "4) Gestionar usuarios y roles"
    echo "5) Generar reporte de logs"
    echo "6) Generar reporte maestro"
    echo "7) Ver automatizacion recomendada"
    echo "8) Ejecutar proyecto completo"
    echo "9) Ver reportes recientes"
    echo "10) Salir"
    echo "============================================================"
    read -r -p "Elige una opcion: " opcion_usuario

    case "$opcion_usuario" in
        1)
            bash "$CARPETA_SCRIPT/preparar_entorno_prueba.sh" --config "$archivo_config" --escenario mixto
            pausar_pantalla
            ;;
        2)
            bash "$CARPETA_SCRIPT/copias_seguridad.sh" --config "$archivo_config" --etiqueta menu
            pausar_pantalla
            ;;
        3)
            bash "$CARPETA_SCRIPT/monitorear_logs.sh" --config "$archivo_config" --modo completo --lineas 500 || true
            pausar_pantalla
            ;;
        4)
            bash "$CARPETA_SCRIPT/gestionar_roles.sh" --config "$archivo_config" --alcance laboratorio --aplicar
            pausar_pantalla
            ;;
        5)
            bash "$CARPETA_SCRIPT/generar_reporte_logs.sh" --config "$archivo_config" --con-respaldo
            pausar_pantalla
            ;;
        6)
            bash "$CARPETA_SCRIPT/generar_reporte_maestro.sh" --config "$archivo_config" --con-bundle
            pausar_pantalla
            ;;
        7)
            bash "$CARPETA_SCRIPT/programar_tareas.sh" ver --config "$archivo_config"
            pausar_pantalla
            ;;
        8)
            bash "$CARPETA_SCRIPT/ejecutar_todo.sh" --config "$archivo_config" --escenario mixto --alcance-roles laboratorio --etiqueta final
            pausar_pantalla
            ;;
        9)
            mostrar_reportes_recientes
            pausar_pantalla
            ;;
        10)
            echo "Saliendo del proyecto final."
            break
            ;;
        *)
            echo "Opcion no valida."
            ;;
    esac
done
