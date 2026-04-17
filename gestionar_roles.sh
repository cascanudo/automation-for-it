#!/usr/bin/env bash
#
# gestionar_roles.sh
# Gestion de usuarios y permisos basada en roles.
#
# Dos dimensiones:
#   alcance: laboratorio (carpetas de prueba) | sistema (useradd real) | auto
#   modo   : --aplicar ejecuta los cambios, --simular solo planifica
#
# Uso tipico (demo):
#   ./gestionar_roles.sh --alcance laboratorio --aplicar
#

set -euo pipefail
IFS=$'\n\t'

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/biblioteca/comun.sh"

activar_trampa_errores

mostrar_ayuda() {
    cat <<'EOF'
uso: gestionar_roles.sh [opciones]

  -c | --config FILE      archivo .conf del proyecto
  -a | --alcance X        auto | laboratorio | sistema
       --aplicar          ejecuta los cambios (default)
       --simular          dry-run: muestra el plan y no toca nada
  -h | --help             esta ayuda
EOF
}

archivo_config="$ARCHIVO_CONFIG_PREDETERMINADO"
alcance=""
modo="aplicar"

# parseo hibrido: uso getopts para las cortas y luego reviso las largas.
# Se que podria hacerlo todo manual pero getopts me parece mas limpio
# para flags con valor corto.
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--config)   archivo_config=$2; shift 2 ;;
        -a|--alcance)  alcance=$2; shift 2 ;;
           --aplicar)  modo="aplicar";  shift ;;
           --simular)  modo="simular";  shift ;;
        -h|--help)     mostrar_ayuda; exit 0 ;;
        *) terminar_con_error "opcion no reconocida: $1 (use --help)" ;;
    esac
done

cargar_configuracion "$archivo_config"
inicializar_entorno

exigir_comando awk
exigir_archivo_lectura "$ARCHIVO_ROLES"
exigir_archivo_lectura "$ARCHIVO_USUARIOS"

# TSVs editados en Windows traen \r al final. Limpiamos antes de leer.
sanear_crlf "$ARCHIVO_ROLES"
sanear_crlf "$ARCHIVO_USUARIOS"

alcance_real="$(resolver_alcance_roles "${alcance:-$ALCANCE_ROLES_PREDETERMINADO}")"
id="$(id_ejecucion)"
ahora="$(marca_tiempo)"

archivo_reporte="$CARPETA_REPORTES/reporte_usuarios_${id}.txt"
archivo_reporte_ultimo="$CARPETA_REPORTES/ultimo_reporte_usuarios.txt"
archivo_detalle="$CARPETA_TEMPORAL/detalle_usuarios_${id}.tsv"
archivo_grupos="$CARPETA_TEMPORAL/grupos_usuarios_${id}.tsv"

: > "$archivo_detalle"

creados=0
retirados=0
errores=0

# chequeo defensivo: si piden tocar el sistema real sin ser root, cortamos ya
if [[ "$alcance_real" == "sistema" && "$modo" == "aplicar" ]]; then
    ejecutando_como_root || terminar_con_error "alcance=sistema + aplicar requiere root"
fi

# ----- loop principal sobre usuarios.tsv -----
while IFS=$'\t' read -r usuario nombre_completo rol shell_usuario estado_usuario || [[ -n "${usuario:-}" ]]; do
    [[ -n "$usuario" ]] || continue
    [[ "$usuario" == "usuario" ]] && continue     # salta el header

    # busco el rol en el catalogo; si no existe, marco error y sigo
    fila_rol=$(awk -F'\t' -v r="$rol" 'NR > 1 && $1 == r { print; exit }' "$ARCHIVO_ROLES")
    if [[ -z "$fila_rol" ]]; then
        printf '%s\t%s\t%s\t%s\t%s\tvalidacion\tERROR\tRol no definido\n' \
            "$ahora" "$alcance_real" "$usuario" "$rol" "$estado_usuario" >> "$ARCHIVO_HISTORIAL_USUARIOS"
        printf '%s\t%s\t%s\tERROR\tRol no definido\n' "$usuario" "$rol" "$estado_usuario" >> "$archivo_detalle"
        errores=$((errores + 1))
        continue
    fi

    IFS=$'\t' read -r _ grupo carpeta_compartida modo_directorio descripcion_rol <<< "$fila_rol"
    accion="planificado"
    resultado="OK"

    if [[ "$alcance_real" == "laboratorio" ]]; then
        carpeta_rol="$CARPETA_ROLES_LAB/$carpeta_compartida"
        carpeta_usuario="$CARPETA_USUARIOS_LAB/$usuario"
        carpeta_home="$carpeta_usuario/home"
        perfil="$carpeta_usuario/perfil_usuario.env"
        acceso="$carpeta_usuario/resumen_acceso.txt"

        if [[ "$estado_usuario" == "ausente" ]]; then
            if [[ "$modo" == "aplicar" && -d "$carpeta_usuario" ]]; then
                rm -rf "$carpeta_usuario"
                accion="retirado"
            else
                accion="retiro_planificado"
            fi
            retirados=$((retirados + 1))
        else
            if [[ "$modo" == "aplicar" ]]; then
                asegurar_directorio "$carpeta_rol"
                asegurar_directorio "$carpeta_home"
                chmod "$modo_directorio" "$carpeta_rol" 2>/dev/null || true
                chmod 750 "$carpeta_home" 2>/dev/null || true
                cat > "$perfil" <<EOF
USUARIO=$usuario
NOMBRE=$nombre_completo
ROL=$rol
GRUPO=$grupo
SHELL=$shell_usuario
DESCRIPCION_ROL=$descripcion_rol
EOF
                cat > "$acceso" <<EOF
Usuario: $usuario
Nombre completo: $nombre_completo
Rol asignado: $rol
Grupo asociado: $grupo
Carpeta compartida: $carpeta_rol
Shell configurado: $shell_usuario
EOF
                accion="provisionado"
            else
                accion="provision_planificado"
            fi
            creados=$((creados + 1))
            printf '%s\t%s\n' "$grupo" "$usuario" >> "$archivo_grupos"
        fi
    else
        # --- alcance sistema ---
        exigir_comando getent
        exigir_comando groupadd
        exigir_comando useradd
        exigir_comando userdel
        exigir_comando usermod
        exigir_comando install

        carpeta_rol="$RUTA_BASE_ROLES_SISTEMA/$carpeta_compartida"

        if [[ "$modo" == "simular" ]]; then
            if [[ "$estado_usuario" == "ausente" ]]; then
                accion="retiro_sistema_planificado"; retirados=$((retirados + 1))
            else
                accion="alta_sistema_planificada"; creados=$((creados + 1))
            fi
        else
            getent group "$grupo" >/dev/null || groupadd "$grupo"
            install -d -m "$modo_directorio" -o root -g "$grupo" "$carpeta_rol"

            if [[ "$estado_usuario" == "ausente" ]]; then
                if id "$usuario" >/dev/null 2>&1; then
                    userdel -r "$usuario"
                    accion="retirado_sistema"
                else
                    accion="ya_no_existia"
                fi
                retirados=$((retirados + 1))
            else
                if id "$usuario" >/dev/null 2>&1; then
                    usermod -c "$nombre_completo" -s "$shell_usuario" -g "$grupo" "$usuario"
                    accion="actualizado_sistema"
                else
                    useradd -m -c "$nombre_completo" -s "$shell_usuario" -g "$grupo" "$usuario"
                    accion="creado_sistema"
                fi
                creados=$((creados + 1))
            fi
        fi
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$ahora" "$alcance_real" "$usuario" "$rol" "$estado_usuario" "$accion" "$resultado" "$descripcion_rol" \
        >> "$ARCHIVO_HISTORIAL_USUARIOS"
    printf '%s\t%s\t%s\t%s\t%s\n' \
        "$usuario" "$rol" "$estado_usuario" "$accion" "$resultado" \
        >> "$archivo_detalle"
done < "$ARCHIVO_USUARIOS"

{
    imprimir_separador
    echo "GESTION DE USUARIOS Y PERMISOS BASADA EN ROLES"
    imprimir_separador
    imprimir_dato "Proyecto"            "$NOMBRE_PROYECTO"
    imprimir_dato "Fecha de ejecucion"  "$ahora"
    imprimir_dato "Alcance usado"       "$alcance_real"
    imprimir_dato "Modo de trabajo"     "$modo"
    imprimir_dato "Usuarios activos"    "$creados"
    imprimir_dato "Usuarios retirados"  "$retirados"
    imprimir_dato "Errores encontrados" "$errores"
    echo
    echo "Detalle por usuario:"
    if [[ -s "$archivo_detalle" ]]; then
        awk -F'\t' '{ printf " - %s | rol=%s | estado=%s | accion=%s | resultado=%s\n", $1,$2,$3,$4,$5 }' "$archivo_detalle"
    else
        echo " - no se procesaron usuarios"
    fi
    echo
    echo "Resumen de grupos:"
    if [[ -s "$archivo_grupos" ]]; then
        sort "$archivo_grupos" | awk -F'\t' '
            { miembros[$1] = miembros[$1] " " $2 }
            END { for (g in miembros) printf " - %s =>%s\n", g, miembros[g] }
        '
    else
        echo " - no se generaron grupos en esta corrida"
    fi
} > "$archivo_reporte"

cp "$archivo_reporte" "$archivo_reporte_ultimo"
cat "$archivo_reporte"

if (( errores > 0 )); then
    registrar_advertencia "roles con $errores errores de validacion"
else
    registrar_info "roles ok ($creados activos, $retirados retirados)"
fi
