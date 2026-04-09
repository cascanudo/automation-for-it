#!/usr/bin/env bash
# ============================================================
# ejecutar_todo.sh
# Ejecuta el proyecto completo de principio a fin
# Proyecto Final - Shell Scripting - IDAT 2026-I
# Grupo: Santos, Juarez, Chavez, Taboada
# ============================================================
# Este script corre todos los modulos en orden: primero prepara
# el entorno de prueba, despues hace los respaldos, el monitoreo,
# la gestion de roles y al final genera los reportes.
# Es lo que usamos para validar todo antes de sustentar.

set -euo pipefail
IFS=$'\n\t'

CARPETA_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
archivo_config="$CARPETA_SCRIPT/configuracion/proyecto_final.conf"
escenario_demo="mixto"
alcance_roles="laboratorio"
etiqueta_respaldo="integral"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --escenario)
            escenario_demo=$2
            shift 2
            ;;
        --alcance-roles)
            alcance_roles=$2
            shift 2
            ;;
        --etiqueta)
            etiqueta_respaldo=$2
            shift 2
            ;;
        --config)
            archivo_config=$2
            shift 2
            ;;
        --help|-h)
            cat <<'EOF'
Uso:
  ./ejecutar_todo.sh [--escenario base|critico|mixto] [--alcance-roles laboratorio|sistema|auto] [--etiqueta nombre]
EOF
            exit 0
            ;;
        *)
            echo "Parametro no reconocido: $1" >&2
            exit 1
            ;;
    esac
done

echo ""
echo "============================================================"
echo "  PROYECTO FINAL DE AUTOMATIZACION EN SHELL"
echo "  Escenario: $escenario_demo | Roles: $alcance_roles"
echo "============================================================"

echo ""
echo "------------------------------------------------------------"
echo "  PASO 1/6: Preparando entorno de prueba..."
echo "------------------------------------------------------------"
bash "$CARPETA_SCRIPT/preparar_entorno_prueba.sh" --config "$archivo_config" --escenario "$escenario_demo"

echo ""
echo "------------------------------------------------------------"
echo "  PASO 2/6: Ejecutando copias de seguridad..."
echo "------------------------------------------------------------"
bash "$CARPETA_SCRIPT/copias_seguridad.sh" --config "$archivo_config" --etiqueta "$etiqueta_respaldo"

echo ""
echo "------------------------------------------------------------"
echo "  PASO 3/6: Ejecutando monitoreo de logs..."
echo "------------------------------------------------------------"
bash "$CARPETA_SCRIPT/monitorear_logs.sh" --config "$archivo_config" --modo completo --lineas 500 || true

echo ""
echo "------------------------------------------------------------"
echo "  PASO 4/6: Gestionando usuarios y roles..."
echo "------------------------------------------------------------"
bash "$CARPETA_SCRIPT/gestionar_roles.sh" --config "$archivo_config" --alcance "$alcance_roles" --aplicar

echo ""
echo "------------------------------------------------------------"
echo "  PASO 5/6: Generando reporte diario de monitoreo..."
echo "------------------------------------------------------------"
bash "$CARPETA_SCRIPT/generar_reporte_logs.sh" --config "$archivo_config" --con-respaldo

echo ""
echo "------------------------------------------------------------"
echo "  PASO 6/6: Generando reporte maestro..."
echo "------------------------------------------------------------"
bash "$CARPETA_SCRIPT/generar_reporte_maestro.sh" --config "$archivo_config" --con-bundle

echo ""
echo "============================================================"
echo "  PROYECTO COMPLETADO - Todos los modulos ejecutados"
echo "  Revisa la carpeta 'reportes/' para ver los resultados."
echo "============================================================"
