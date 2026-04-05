# Proyecto Final de Automatizacion en Shell

Trabajo final del curso de Shell Scripting - IDAT 2026-I.

**Integrantes:**
- Manuel Santos Diaz
- Maximiliano Juarez Arevalo
- Gabriel Chavez Velasquez
- Juan Taboada Rosales

## Que hace este proyecto

El area de sistemas de una empresa necesitaba automatizar tres tareas que se venian haciendo a mano y que generaban errores y demoras. Nosotros desarrollamos una solucion en Bash que cubre esas tres necesidades:

1. **Copias de seguridad diarias** de directorios importantes, con reporte automatico del resultado.
2. **Monitoreo de logs** con deteccion de eventos criticos clasificados por severidad.
3. **Gestion de usuarios y permisos** basada en roles definidos por el equipo de operaciones.

Todo funciona de forma integrada: los tres modulos comparten configuracion, generan evidencia verificable y se pueden ejecutar por separado o en conjunto.

## Estructura del proyecto

```
.
├── menu_principal.sh              # Menu interactivo para la sustentacion
├── ejecutar_todo.sh               # Corre el proyecto completo de principio a fin
├── copias_seguridad.sh            # Modulo 1: respaldos diarios
├── monitorear_logs.sh             # Modulo 2: monitoreo de logs
├── gestionar_roles.sh             # Modulo 3: gestion de usuarios y roles
├── generar_reporte_logs.sh        # Consolida el reporte diario del monitoreo
├── generar_reporte_maestro.sh     # Arma el reporte general del proyecto
├── preparar_entorno_prueba.sh     # Limpia y prepara el entorno de demo
├── simular_logs.sh                # Genera logs de prueba con distintos escenarios
├── programar_tareas.sh            # Muestra la automatizacion con cron
├── biblioteca/
│   └── comun.sh                   # Funciones compartidas, validaciones y rutas
├── configuracion/
│   ├── proyecto_final.conf        # Configuracion central del proyecto
│   ├── patrones.conf              # Reglas de deteccion para el monitoreo
│   ├── roles.tsv                  # Definicion de roles y permisos
│   └── usuarios.tsv               # Lista de usuarios con su rol y estado
├── recursos_prueba/               # Archivos de ejemplo para probar los respaldos
├── logs_prueba/                   # Logs generados para las pruebas
├── reportes/                      # Reportes generados por cada modulo
├── respaldos/                     # Paquetes comprimidos de los respaldos
├── estado/                        # Historial y checkpoints de ejecucion
├── buzon/                         # Evidencia de envio de reportes
├── laboratorio/                   # Usuarios y roles creados en modo prueba
└── temporal/                      # Archivos intermedios de procesamiento
```

## Como probarlo

La forma mas rapida de ver todo funcionando es ejecutar el flujo completo:

```bash
cd subir_a_github
chmod +x *.sh biblioteca/*.sh
./ejecutar_todo.sh --escenario mixto --alcance-roles laboratorio --etiqueta final
```

Esto hace lo siguiente en orden:
1. Prepara el entorno limpio con datos de prueba
2. Genera los respaldos comprimidos de las carpetas configuradas
3. Analiza los logs y clasifica los eventos por severidad
4. Procesa los usuarios segun los roles definidos
5. Genera el reporte diario del monitoreo
6. Arma el reporte maestro con el consolidado de todo

Tambien se puede usar el menu interactivo para ir ejecutando cada parte por separado:

```bash
./menu_principal.sh
```

## Que evidencia genera

Despues de ejecutar el proyecto, estos son los archivos mas importantes que quedan:

| Archivo | Que contiene |
|---------|-------------|
| `reportes/ultimo_reporte_respaldos.txt` | Detalle de cada respaldo generado |
| `reportes/ultimo_resumen_monitoreo.txt` | Alertas detectadas en los logs |
| `reportes/ultimo_reporte_logs.txt` | Reporte diario del monitoreo |
| `reportes/ultimo_reporte_usuarios.txt` | Resultado de la gestion de roles |
| `reportes/ultimo_reporte_maestro.txt` | Consolidado general del proyecto |
| `respaldos/paquete_maestro_*.tar.gz` | Paquete comprimido con toda la evidencia |
| `buzon/envio_*` | Registro del envio simulado de reportes |

## Automatizacion con cron

Para que los modulos se ejecuten solos en un servidor Linux, el script `programar_tareas.sh` configura las entradas de crontab:

```bash
./programar_tareas.sh ver        # Muestra las tareas programadas
./programar_tareas.sh instalar   # Instala las tareas en cron
./programar_tareas.sh quitar     # Retira las tareas de cron
```

Las tareas programadas son:
- **02:00** - Respaldo diario de los directorios configurados
- **Cada 15 min** - Monitoreo incremental de los logs
- **06:15** - Auditoria de usuarios y roles
- **23:55** - Generacion del reporte maestro del dia

## Herramientas que usamos

Los scripts aprovechan varias utilidades de Linux que fuimos aprendiendo en el curso:

- `awk` para procesar los archivos tabulados y los reportes
- `sed` para limpiar y normalizar datos antes de procesarlos
- `grep` para filtrar eventos por fecha o severidad
- `tar` para comprimir los respaldos
- `find` para buscar archivos por tipo y antiguedad
- `sort` y `wc` para ordenar y contar resultados
- `cron` para la ejecucion automatica programada
- `chmod` y `mkdir` para gestionar permisos y directorios

## Mejoras respecto al examen parcial

En el parcial teniamos scripts basicos que funcionaban de forma independiente. Para el final mejoramos varias cosas:

- Los scripts ahora comparten una biblioteca comun (`comun.sh`) en vez de repetir codigo.
- Toda la configuracion esta centralizada en archivos `.conf` y `.tsv`.
- Agregamos validaciones de parametros, existencia de archivos y herramientas.
- Los reportes son mas completos y dejan trazabilidad de cada ejecucion.
- El proyecto se puede ejecutar completo con un solo comando.
- Incorporamos programacion automatica con cron.
- Separamos el modo laboratorio del modo sistema para que la demo sea segura.

## Requisitos

- Bash 4.0 o superior
- Utilidades estandar de Linux: `tar`, `awk`, `sed`, `grep`, `find`, `sort`, `wc`, `date`
- Para la programacion automatica: `cron` (opcional, solo si se quiere instalar)
