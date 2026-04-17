# Automatización de operaciones en Shell

Trabajo final del curso de Shell Scripting — IDAT 2026-I.

**Integrantes**

- Manuel Santos Díaz
- Maximiliano Juárez Arévalo
- Gabriel Chávez Velásquez
- Juan Taboada Rosales

## Qué hace el proyecto

El área de sistemas de una empresa hipotética necesitaba automatizar tres tareas que se venían haciendo a mano y que generaban demoras y errores. Nuestra solución en Bash cubre las tres:

1. **Copias de seguridad diarias** de directorios clave, con reporte y manifiesto verificable.
2. **Monitoreo de logs** con detección de eventos críticos clasificados por severidad.
3. **Gestión de usuarios y permisos** basada en roles definidos en un catálogo.

Los tres módulos comparten configuración, dejan historial acumulado y pueden correrse por separado o todos juntos con un solo comando.

## Requisitos

- Linux (Ubuntu, Debian, CentOS) o WSL / Git Bash en Windows.
- Bash 4.0 o superior (`bash --version`).
- Utilidades estándar: `tar`, `awk`, `sed`, `grep`, `find`, `sort`, `wc`, `date`, `chmod`, `mkdir`, `sha256sum`.
- `cron` si se quiere programar la ejecución automática (opcional).

## Cómo correr el proyecto

### 1. Clonar e instalar

```bash
git clone https://github.com/cascanudo/automation-for-it.git
cd automation-for-it
./instalar.sh
```

`instalar.sh` da permisos de ejecución a los `.sh` y verifica que estén las dependencias. Si falta algo, te avisa.

### 2. Ejecución completa de una sola pasada

```bash
./ejecutar_todo.sh --escenario mixto --alcance-roles laboratorio --etiqueta final
```

Esto hace, en orden:

1. Limpia reportes viejos y siembra datos de ejemplo.
2. Respalda las carpetas configuradas y genera manifiesto con hash SHA256.
3. Monitorea los logs aplicando las reglas de `configuracion/patrones.conf`.
4. Procesa usuarios/roles en modo laboratorio (sin tocar el sistema real).
5. Genera el reporte diario consolidado.
6. Genera el reporte maestro con evidencia de los tres módulos.

### 3. Menú interactivo (para la demo)

```bash
./menu_principal.sh
```

Diez opciones numeradas; ideal para mostrar cada módulo por separado sin tener que recordar flags.

## Ejecutar los módulos por separado

```bash
# Copias de seguridad
./copias_seguridad.sh --etiqueta manual

# Monitoreo de logs (modo completo, últimas 500 líneas)
./monitorear_logs.sh --modo completo --lineas 500

# Gestión de usuarios y roles (dry-run)
./gestionar_roles.sh --alcance laboratorio --simular

# Reporte diario con bundle
./generar_reporte_logs.sh --con-respaldo

# Reporte maestro con paquete
./generar_reporte_maestro.sh --con-bundle

# Resembrar entorno de prueba desde cero
./preparar_entorno_prueba.sh --escenario mixto
```

Todos los scripts aceptan `--help`.

## Qué evidencia queda

| Archivo | Contenido |
|---|---|
| `reportes/ultimo_reporte_respaldos.txt` | Detalle de cada respaldo (carpetas, pesos, hashes) |
| `reportes/ultimo_resumen_monitoreo.txt` | Alertas detectadas por fuente y severidad |
| `reportes/ultimo_reporte_logs.txt` | Reporte diario consolidado con recomendaciones |
| `reportes/ultimo_reporte_usuarios.txt` | Resultado de la gestión de roles por usuario |
| `reportes/ultimo_reporte_maestro.txt` | Consolidado general de los tres módulos |
| `respaldos/paquete_maestro_*.tar.gz` | Paquete comprimido con los reportes principales |
| `buzon/envio_*` | Registro del envío simulado por correo |
| `laboratorio/usuarios/` | Perfiles y carpetas creados en modo laboratorio |
| `estado/alertas_historial.tsv` | Historial acumulado de todas las alertas |

## Estructura

```
.
├── instalar.sh                    # Permisos + check de dependencias
├── ejecutar_todo.sh               # Orquestador de punta a punta
├── menu_principal.sh              # Menú interactivo
├── copias_seguridad.sh            # Módulo 1: respaldos
├── monitorear_logs.sh             # Módulo 2: monitoreo
├── gestionar_roles.sh             # Módulo 3: usuarios y roles
├── generar_reporte_logs.sh        # Reporte diario del monitoreo
├── generar_reporte_maestro.sh     # Reporte general consolidado
├── preparar_entorno_prueba.sh     # Limpia y siembra datos
├── simular_logs.sh                # Genera logs de prueba
├── programar_tareas.sh            # Instala/quita entradas de cron
├── biblioteca/comun.sh            # Funciones compartidas
├── configuracion/
│   ├── proyecto_final.conf        # Rutas y parámetros
│   ├── patrones.conf              # Reglas de detección
│   ├── roles.tsv                  # Catálogo de roles
│   └── usuarios.tsv               # Lista de usuarios
├── recursos_prueba/               # Datos de ejemplo para respaldar
├── logs_prueba/                   # Logs sembrados
├── reportes/ respaldos/ estado/ buzon/ laboratorio/ temporal/
```

## Automatización con cron

```bash
./programar_tareas.sh ver        # ver bloque recomendado
./programar_tareas.sh instalar   # agregarlo a tu crontab
./programar_tareas.sh quitar     # sacarlo
```

| Horario | Tarea |
|---|---|
| 02:00 | Respaldo diario |
| cada 15 min | Monitoreo incremental |
| 06:15 | Auditoría de roles (simulación) |
| 23:55 | Reporte maestro con bundle |

Si cron no está disponible (WSL sin servicio, por ejemplo), `programar_tareas.sh ver` muestra el bloque para copiarlo a mano con `crontab -e`.

## Herramientas usadas

| Herramienta | Para qué |
|---|---|
| `awk` | Cruce de patrones, conteos, formato de reportes |
| `sed` | Limpieza de caracteres de control y CRLF |
| `grep` | Filtrado de historial por fecha |
| `tar` | Respaldos y bundles de evidencia |
| `find` | Búsqueda y limpieza de artefactos |
| `sort` / `wc` | Ordenamiento y conteo |
| `cron` | Programación de ejecuciones |
| `sha256sum` | Integridad de paquetes |

## Exit codes del monitoreo

El módulo `monitorear_logs.sh` usa códigos de salida para que pueda encadenarse con otros procesos:

- `0` — sin alertas críticas.
- `1` — error de ejecución (parámetro inválido, archivo no legible, etc).
- `2` — se detectaron alertas críticas (no es un error, es una señal).

`ejecutar_todo.sh` captura el `2` y lo muestra como advertencia, no como fallo.

## Limitaciones conocidas

- El envío de reportes por correo está **simulado**: se deja un archivo en `buzon/` con los metadatos del envío. Integrar `msmtp` o `sendmail` real queda fuera del alcance del curso.
- El modo `--alcance sistema` de `gestionar_roles.sh` crea usuarios reales con `useradd` y requiere root. Lo validamos en una VM Ubuntu; para la sustentación usamos `laboratorio`.
- Probado con Bash 4.4+ y 5.x. Bash 3 (macOS viejo) no soporta arrays asociativos.
