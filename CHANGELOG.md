# Changelog

## v1.1.0

- Refactor de biblioteca/comun.sh: separador `---` en vez de banner de asteriscos.
- `activar_trampa_errores`: trampa ERR opcional que imprime archivo:linea cuando algo falla.
- `sanear_crlf`: limpia \r de TSV editados en Windows antes de leerlos.
- `ejecutar_todo.sh` ahora captura el exit 2 del monitoreo y lo distingue de un error real.
- `preparar_entorno_prueba.sh` deja `inventario.txt` con un valor fijo para no ensuciar `git status` en cada corrida.
- Validaciones extra: `patrones.conf` debe tener al menos una regla; `CARPETA_REPORTES` debe ser escribible.
- Nuevo `instalar.sh` que da permisos y verifica dependencias.
- Reemplazo de `echo | sed` por expansion bash en sanitizacion de nombres.
- Limpieza general de comentarios y uniformizacion del parseo de argumentos.

## v1.0.0

- Modulo de copias de seguridad con manifiesto, hash SHA256 y retencion.
- Modulo de monitoreo con patrones por severidad (CRITICAL, HIGH, MEDIUM, LOW) y modos completo/incremental.
- Modulo de gestion de roles con alcance laboratorio/sistema y modo aplicar/simular.
- Reporte diario y reporte maestro consolidado.
- Automatizacion con cron: respaldos 02:00, monitoreo cada 15 min, roles 06:15, maestro 23:55.
- Menu interactivo para la sustentacion.
- README y estructura inicial del proyecto.
