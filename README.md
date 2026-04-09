# Proyecto Final de Automatizacion en Shell

Trabajo final del curso de Shell Scripting - IDAT 2026-I.

**Integrantes:**
- Manuel Santos Diaz
- Maximiliano Juarez Arevalo
- Gabriel Chavez Velasquez
- Juan Taboada Rosales

---

## Que hace este proyecto

El area de sistemas de una empresa necesitaba automatizar tres tareas que se venian haciendo a mano y que generaban errores y demoras. Nosotros desarrollamos una solucion en Bash que cubre esas tres necesidades:

1. **Copias de seguridad diarias** de directorios importantes, con reporte automatico del resultado.
2. **Monitoreo de logs** con deteccion de eventos criticos clasificados por severidad.
3. **Gestion de usuarios y permisos** basada en roles definidos por el equipo de operaciones.

Todo funciona de forma integrada: los tres modulos comparten configuracion, generan evidencia verificable y se pueden ejecutar por separado o en conjunto.

---

## Requisitos previos

Antes de empezar, asegurate de tener lo siguiente:

- **Sistema operativo:** Linux (Ubuntu, Debian, CentOS) o cualquier entorno con Bash disponible (WSL en Windows tambien funciona).
- **Bash 4.0 o superior.** Para verificar tu version ejecuta: `bash --version`
- **Utilidades estandar de Linux:** `tar`, `awk`, `sed`, `grep`, `find`, `sort`, `wc`, `date`, `chmod`, `mkdir`. Normalmente ya vienen instaladas en cualquier distribucion.
- **Git** (solo si quieres clonar el repositorio en vez de descargarlo como ZIP).
- **cron** (opcional, solo si quieres instalar la ejecucion automatica programada).

---

## Como descargar el proyecto

### Opcion 1: Clonar con Git

Abre una terminal y ejecuta:

```bash
git clone https://github.com/cascanudo/automation-for-it.git
```

Esto crea una carpeta llamada `automation-for-it` con todo el proyecto adentro.

### Opcion 2: Descargar como ZIP

1. Ve a https://github.com/cascanudo/automation-for-it
2. Haz clic en el boton verde **Code** y luego en **Download ZIP**.
3. Descomprime el archivo en la ubicacion que prefieras.

---

## Como ejecutar el proyecto paso a paso

### Paso 1: Entrar a la carpeta del proyecto

Si clonaste con Git:

```bash
cd automation-for-it
```

Si descargaste el ZIP y lo descomprimiste, entra a la carpeta que se creo (puede llamarse `automation-for-it-main`):

```bash
cd automation-for-it-main
```

### Paso 2: Dar permisos de ejecucion a los scripts

Los archivos `.sh` necesitan permiso de ejecucion para poder correr. Ejecuta este comando una sola vez:

```bash
chmod +x *.sh biblioteca/*.sh
```

### Paso 3: Ejecutar el proyecto completo

Este es el comando principal. Corre todos los modulos en orden y genera toda la evidencia:

```bash
./ejecutar_todo.sh --escenario mixto --alcance-roles laboratorio --etiqueta final
```

**Que hace este comando en orden:**

1. **Prepara el entorno:** Limpia archivos de corridas anteriores y siembra datos de ejemplo (logs simulados, archivos de configuracion de prueba, etc.).
2. **Ejecuta las copias de seguridad:** Comprime las carpetas configuradas, genera un manifiesto con hash SHA256 y deja un registro del envio del reporte.
3. **Ejecuta el monitoreo de logs:** Analiza los archivos de log linea por linea, los cruza contra las reglas de deteccion y clasifica cada hallazgo por severidad (CRITICAL, HIGH, MEDIUM, LOW).
4. **Gestiona usuarios y roles:** Lee el archivo de usuarios, valida los roles asignados y genera la estructura de carpetas y perfiles en modo laboratorio (sin tocar usuarios reales del sistema).
5. **Genera el reporte diario de monitoreo:** Consolida los eventos del dia con desglose por fuente, severidad y recomendaciones.
6. **Genera el reporte maestro:** Junta la evidencia de los tres modulos en un solo reporte final.

### Paso 4 (opcional): Usar el menu interactivo

Si prefieres ir ejecutando cada modulo por separado, puedes usar el menu:

```bash
./menu_principal.sh
```

El menu muestra 10 opciones numeradas. Solo escribe el numero y presiona Enter para ejecutar la accion correspondiente.

---

## Como ejecutar cada modulo por separado

Si quieres correr solo un modulo especifico, estos son los comandos:

### Copias de seguridad

```bash
./copias_seguridad.sh --config configuracion/proyecto_final.conf --etiqueta manual
```

Genera paquetes comprimidos de las carpetas definidas en la configuracion y deja un reporte en `reportes/`.

### Monitoreo de logs

```bash
./monitorear_logs.sh --config configuracion/proyecto_final.conf --modo completo --lineas 500
```

Revisa los logs y detecta eventos segun las reglas definidas en `configuracion/patrones.conf`. El parametro `--modo completo` analiza las ultimas 500 lineas; si usas `--modo incremental`, solo revisa las lineas nuevas desde la ultima corrida.

### Gestion de usuarios y roles

```bash
./gestionar_roles.sh --config configuracion/proyecto_final.conf --alcance laboratorio --aplicar
```

Procesa el archivo `configuracion/usuarios.tsv` y genera perfiles, carpetas y permisos en modo laboratorio. Si solo quieres ver que haria sin aplicar cambios, usa `--simular` en lugar de `--aplicar`.

### Generar reporte diario del monitoreo

```bash
./generar_reporte_logs.sh --config configuracion/proyecto_final.conf --con-respaldo
```

### Generar reporte maestro (consolidado)

```bash
./generar_reporte_maestro.sh --config configuracion/proyecto_final.conf --con-bundle
```

### Preparar el entorno de prueba desde cero

```bash
./preparar_entorno_prueba.sh --config configuracion/proyecto_final.conf --escenario mixto
```

Esto borra todos los archivos generados y vuelve a sembrar datos de ejemplo. Util si quieres empezar la demo desde cero.

> **Nota:** Cada script acepta `--help` para ver todas sus opciones. Por ejemplo: `./copias_seguridad.sh --help`

---

## Que evidencia genera el proyecto

Despues de ejecutar el proyecto, estos son los archivos mas importantes que quedan:

| Archivo | Que contiene |
|---------|-------------|
| `reportes/ultimo_reporte_respaldos.txt` | Detalle de cada respaldo generado (carpetas, pesos, hashes) |
| `reportes/ultimo_resumen_monitoreo.txt` | Resumen de alertas detectadas por fuente y severidad |
| `reportes/ultimo_reporte_logs.txt` | Reporte diario consolidado con recomendaciones |
| `reportes/ultimo_reporte_usuarios.txt` | Resultado de la gestion de roles por usuario |
| `reportes/ultimo_reporte_maestro.txt` | Consolidado general de los tres modulos |
| `respaldos/paquete_maestro_*.tar.gz` | Paquete comprimido con los reportes principales |
| `buzon/envio_*` | Registro simulado del envio de reportes por correo |
| `laboratorio/usuarios/` | Perfiles y carpetas creados para cada usuario en modo prueba |
| `estado/alertas_historial.tsv` | Historial acumulado de todas las alertas detectadas |

---

## Estructura del proyecto

```
.
├── menu_principal.sh              # Menu interactivo para la sustentacion
├── ejecutar_todo.sh               # Corre el proyecto completo de principio a fin
├── copias_seguridad.sh            # Modulo 1: respaldos diarios con manifiesto
├── monitorear_logs.sh             # Modulo 2: monitoreo de logs por severidad
├── gestionar_roles.sh             # Modulo 3: gestion de usuarios y permisos
├── generar_reporte_logs.sh        # Reporte diario consolidado del monitoreo
├── generar_reporte_maestro.sh     # Reporte general que junta los tres modulos
├── preparar_entorno_prueba.sh     # Limpia y siembra datos de ejemplo
├── simular_logs.sh                # Genera logs de prueba (base, critico, mixto)
├── programar_tareas.sh            # Configura la automatizacion con cron
├── biblioteca/
│   └── comun.sh                   # Funciones compartidas por todos los scripts
├── configuracion/
│   ├── proyecto_final.conf        # Rutas, parametros y valores por defecto
│   ├── patrones.conf              # Reglas de deteccion (severidad + regex)
│   ├── roles.tsv                  # Definicion de roles, grupos y permisos
│   └── usuarios.tsv               # Lista de usuarios con rol y estado
├── recursos_prueba/               # Archivos de ejemplo para probar los respaldos
├── logs_prueba/                   # Logs generados por simular_logs.sh
├── reportes/                      # Reportes generados por cada modulo
├── respaldos/                     # Paquetes comprimidos de los respaldos
├── estado/                        # Historial y checkpoints de ejecucion
├── buzon/                         # Registros de envio simulado de reportes
├── laboratorio/                   # Usuarios y roles creados en modo prueba
└── temporal/                      # Archivos intermedios de procesamiento
```

---

## Automatizacion con cron

Para que los modulos se ejecuten automaticamente en un servidor Linux, usamos `programar_tareas.sh`:

```bash
# Ver que tareas se instalarian
./programar_tareas.sh ver

# Instalar las tareas en el crontab del usuario actual
./programar_tareas.sh instalar

# Quitar las tareas si ya no se necesitan
./programar_tareas.sh quitar
```

Las tareas que se programan son:

| Horario | Que ejecuta |
|---------|-------------|
| Todos los dias a las 02:00 | Respaldo diario de los directorios configurados |
| Cada 15 minutos | Monitoreo incremental de los logs |
| Todos los dias a las 06:15 | Auditoria de usuarios y roles (modo simulacion) |
| Todos los dias a las 23:55 | Generacion del reporte maestro del dia |

> **Nota:** Si cron no esta disponible en tu entorno (por ejemplo en WSL sin configurar), el script muestra el bloque recomendado para que lo copies manualmente.

---

## Herramientas utilizadas

Los scripts aprovechan varias utilidades estandar de Linux:

| Herramienta | Para que la usamos |
|-------------|-------------------|
| `awk` | Procesar archivos tabulados, cruzar patrones, generar conteos y formatear reportes |
| `sed` | Limpiar caracteres de control en logs, normalizar rutas, sanitizar nombres de archivo |
| `grep` | Filtrar historial por fecha, buscar patrones especificos |
| `tar` | Comprimir respaldos y paquetes de evidencia |
| `find` | Buscar archivos por tipo y antiguedad, limpiar artefactos |
| `sort` / `wc` | Ordenar resultados y contar lineas |
| `cron` | Programar la ejecucion automatica recurrente |
| `chmod` / `mkdir` | Gestionar permisos y crear directorios |
| `sha256sum` | Calcular hash de integridad de los paquetes generados |

---

## Mejoras respecto al examen parcial

En el parcial teniamos scripts basicos que funcionaban de forma independiente. Para el final mejoramos varias cosas:

- Los scripts ahora comparten una **biblioteca comun** (`comun.sh`) en vez de repetir codigo.
- Toda la configuracion esta **centralizada** en archivos `.conf` y `.tsv`.
- Agregamos **validaciones** de parametros, existencia de archivos y herramientas disponibles.
- Los reportes son mas completos y dejan **trazabilidad** de cada ejecucion.
- El proyecto se puede ejecutar completo con **un solo comando**.
- Incorporamos **programacion automatica con cron**.
- Separamos el **modo laboratorio** del modo sistema para que la demo sea segura.
- Usamos **awk y sed** para el procesamiento real de datos, no solo comandos basicos.
