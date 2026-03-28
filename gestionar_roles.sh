#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# ============================================================
# gestionar_roles.sh
# Modulo de gestion de usuarios y permisos basada en roles
# Proyecto Final - Shell Scripting - IDAT 2026-I
# Grupo: Santos, Juarez, Chavez, Taboada
# ============================================================

CARPETA_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$CARPETA_SCRIPT/biblioteca/comun.sh"

mostrar_ayuda() {
    cat <<'EOF'
Uso:
  ./gestionar_roles.sh [--config ruta] [--alcance auto|laboratorio|sistema] [--aplicar|--simular]

Opciones:
  --config    Archivo de configuracion del proyecto.
  --alcance   Define si se trabaja en laboratorio o sobre el sistema real.
  --aplicar   Ejecuta los cambios definidos en el manifiesto.
  --simular   Solo muestra el plan sin aplicar cambios.
  --help      Muestra esta ayuda.
EOF
}

archivo_config="$ARCHIVO_CONFIG_PREDETERMINADO"
alcance_solicitado=""
modo_ejecucion="aplicar"

# El manifiesto puede ejecutarse en modo seguro o en modo real, segun el entorno disponible.
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)
            archivo_config=$2
            shift 2
            ;;
        --alcance)
            alcance_solicitado=$2
            shift 2
            ;;
        --aplicar)
            modo_ejecucion="aplicar"
            shift
            ;;
        --simular)
            modo_ejecucion="simular"
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

exigir_comando awk
exigir_comando sort
exigir_archivo_lectura "$ARCHIVO_ROLES"
exigir_archivo_lectura "$ARCHIVO_USUARIOS"

alcance_real="$(resolver_alcance_roles "${alcance_solicitado:-$ALCANCE_ROLES_PREDETERMINADO}")"
id_actual="$(id_ejecucion)"
fecha_ejecucion="$(marca_tiempo)"
archivo_reporte="$CARPETA_REPORTES/reporte_usuarios_${id_actual}.txt"
archivo_reporte_reciente="$CARPETA_REPORTES/ultimo_reporte_usuarios.txt"
archivo_detalle="$CARPETA_TEMPORAL/detalle_usuarios_${id_actual}.tsv"
archivo_grupos="$CARPETA_TEMPORAL/grupos_usuarios_${id_actual}.tsv"

# Inicializamos el archivo de detalle donde vamos registrando cada accion.
: > "$archivo_detalle"

usuarios_creados=0
usuarios_retirados=0
errores_detectados=0

if [[ "$alcance_real" == "sistema" && "$modo_ejecucion" == "aplicar" ]]; then
    ejecutando_como_root || terminar_con_error "Para aplicar cambios reales en el sistema debes ejecutar como root."
fi

# Leemos cada linea del archivo de usuarios y procesamos la accion que corresponde.
while IFS=$'\t' read -r usuario nombre_completo rol shell_usuario estado_usuario || [[ -n "${usuario:-}" ]]; do
    [[ -n "$usuario" ]] || continue
    if [[ "$usuario" == "usuario" ]]; then
        continue
    fi

    fila_rol=$(awk -F'\t' -v rol_buscado="$rol" 'NR > 1 && $1 == rol_buscado { print $0 }' "$ARCHIVO_ROLES")
    if [[ -z "$fila_rol" ]]; then
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$fecha_ejecucion" "$alcance_real" "$usuario" "$rol" "$estado_usuario" "validacion" "ERROR" "Rol no definido" >> "$ARCHIVO_HISTORIAL_USUARIOS"
        printf '%s\t%s\t%s\t%s\t%s\n' "$usuario" "$rol" "$estado_usuario" "ERROR" "Rol no definido" >> "$archivo_detalle"
        errores_detectados=$((errores_detectados + 1))
        continue
    fi

    IFS=$'\t' read -r _ grupo carpeta_compartida modo_directorio descripcion_rol <<< "$fila_rol"
    accion_realizada="planificado"
    estado_resultado="OK"

    if [[ "$alcance_real" == "laboratorio" ]]; then
        # En modo laboratorio creamos las carpetas y archivos de prueba sin tocar usuarios reales.
        carpeta_rol="$CARPETA_ROLES_LAB/$carpeta_compartida"
        carpeta_usuario="$CARPETA_USUARIOS_LAB/$usuario"
        carpeta_home="$carpeta_usuario/home"
        archivo_perfil="$carpeta_usuario/perfil_usuario.env"
        archivo_acceso="$carpeta_usuario/resumen_acceso.txt"

        if [[ "$estado_usuario" == "ausente" ]]; then
            if [[ "$modo_ejecucion" == "aplicar" && -d "$carpeta_usuario" ]]; then
                rm -rf "$carpeta_usuario"
                accion_realizada="retirado"
            else
                accion_realizada="retiro_planificado"
            fi
            usuarios_retirados=$((usuarios_retirados + 1))
        else
            if [[ "$modo_ejecucion" == "aplicar" ]]; then
                asegurar_directorio "$carpeta_rol"
                asegurar_directorio "$carpeta_home"
                chmod "$modo_directorio" "$carpeta_rol" 2>/dev/null || true
                chmod 750 "$carpeta_home" 2>/dev/null || true
                cat > "$archivo_perfil" <<EOF
USUARIO=$usuario
NOMBRE=$nombre_completo
ROL=$rol
GRUPO=$grupo
SHELL=$shell_usuario
DESCRIPCION_ROL=$descripcion_rol
EOF
                # Nos aseguramos de que no queden espacios en blanco al final de cada linea del perfil.
                sed -i 's/[[:space:]]*$//' "$archivo_perfil"
                cat > "$archivo_acceso" <<EOF
Usuario: $usuario
Nombre completo: $nombre_completo
Rol asignado: $rol
Grupo asociado: $grupo
Carpeta compartida: $carpeta_rol
Shell configurado: $shell_usuario
EOF
                accion_realizada="provisionado"
            else
                accion_realizada="provision_planificado"
            fi
            usuarios_creados=$((usuarios_creados + 1))
            printf '%s\t%s\n' "$grupo" "$usuario" >> "$archivo_grupos"
        fi
    else
        # En modo sistema trabajamos con usuarios y grupos reales del sistema operativo.
        exigir_comando getent
        exigir_comando groupadd
        exigir_comando useradd
        exigir_comando userdel
        exigir_comando usermod
        exigir_comando install

        carpeta_rol="$RUTA_BASE_ROLES_SISTEMA/$carpeta_compartida"

        if [[ "$modo_ejecucion" == "simular" ]]; then
            if [[ "$estado_usuario" == "ausente" ]]; then
                accion_realizada="retiro_sistema_planificado"
                usuarios_retirados=$((usuarios_retirados + 1))
            else
                accion_realizada="alta_sistema_planificada"
                usuarios_creados=$((usuarios_creados + 1))
            fi
        else
            getent group "$grupo" >/dev/null || groupadd "$grupo"
            install -d -m "$modo_directorio" -o root -g "$grupo" "$carpeta_rol"

            if [[ "$estado_usuario" == "ausente" ]]; then
                if id "$usuario" >/dev/null 2>&1; then
                    userdel -r "$usuario"
                    accion_realizada="retirado_sistema"
                else
                    accion_realizada="ya_no_existia"
                fi
                usuarios_retirados=$((usuarios_retirados + 1))
            else
                if id "$usuario" >/dev/null 2>&1; then
                    usermod -c "$nombre_completo" -s "$shell_usuario" -g "$grupo" "$usuario"
                    accion_realizada="actualizado_sistema"
                else
                    useradd -m -c "$nombre_completo" -s "$shell_usuario" -g "$grupo" "$usuario"
                    accion_realizada="creado_sistema"
                fi
                usuarios_creados=$((usuarios_creados + 1))
            fi
        fi
    fi

    # Registramos lo que se hizo con cada usuario para tener trazabilidad completa.
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$fecha_ejecucion" "$alcance_real" "$usuario" "$rol" "$estado_usuario" "$accion_realizada" "$estado_resultado" "$descripcion_rol" >> "$ARCHIVO_HISTORIAL_USUARIOS"
    printf '%s\t%s\t%s\t%s\t%s\n' "$usuario" "$rol" "$estado_usuario" "$accion_realizada" "$estado_resultado" >> "$archivo_detalle"
done < "$ARCHIVO_USUARIOS"

{
    imprimir_separador
    echo "GESTION DE USUARIOS Y PERMISOS BASADA EN ROLES"
    imprimir_separador
    imprimir_dato "Proyecto" "$NOMBRE_PROYECTO"
    imprimir_dato "Fecha de ejecucion" "$fecha_ejecucion"
    imprimir_dato "Alcance usado" "$alcance_real"
    imprimir_dato "Modo de trabajo" "$modo_ejecucion"
    imprimir_dato "Usuarios activos" "$usuarios_creados"
    imprimir_dato "Usuarios retirados" "$usuarios_retirados"
    imprimir_dato "Errores encontrados" "$errores_detectados"
    echo
    echo "Detalle por usuario:"
    if [[ -s "$archivo_detalle" ]]; then
        awk -F'\t' '{ printf " - %s | rol=%s | estado=%s | accion=%s | resultado=%s\n", $1, $2, $3, $4, $5 }' "$archivo_detalle"
    else
        echo " - No se procesaron usuarios."
    fi
    echo
    echo "Resumen de grupos:"
    if [[ -s "$archivo_grupos" ]]; then
        sort "$archivo_grupos" | awk -F'\t' '{ miembros[$1] = miembros[$1] " " $2 } END { for (grupo in miembros) printf " - %s =>%s\n", grupo, miembros[grupo] }'
    else
        echo " - No se generaron grupos en esta corrida."
    fi
} > "$archivo_reporte"

cp "$archivo_reporte" "$archivo_reporte_reciente"
cat "$archivo_reporte"
registrar_info "Modulo de gestion de usuarios finalizado."
