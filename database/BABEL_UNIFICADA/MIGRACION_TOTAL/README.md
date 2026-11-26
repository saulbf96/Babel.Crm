# Migración total legacy -> BABEL_UNIFICADA

Esta carpeta contiene la migración **completa** de las 13 carteras legacy
(`10.80.5.189`) hacia la base local `BABEL_UNIFICADA`, junto con la
reimplementación del comportamiento de los SPs legacy.

## Regla inviolable

En `10.80.5.189` **solo se ejecuta `SELECT`**. Nunca `INSERT`, `UPDATE`,
`DELETE`, `BACKUP`, `ALTER`, `DROP` ni cambios de esquema. Toda escritura es
local. La contraseña se lee de `BABELGESTION.xml` y **nunca** se imprime ni se
persiste en logs.

## Estrategia

1. **Inventario remoto** (`00_inventario_remoto.ps1`): lee `sys.tables`,
   `sys.columns`, `sys.indexes`, `sys.partitions` y `sys.objects` de las 13
   bases. Genera CSV en `inventario/`.
2. **Espejo crudo** (`01_esquema_legacy.sql` + `02_migrar_todo.ps1`): crea el
   esquema `legacy` con una tabla por tabla remota (superset de columnas de las
   13 bases) y copia **todas** las filas con `SqlBulkCopy`, agregando
   `IdCartera` e `IdOrigen`. Así no se pierde ninguna información, aunque su
   significado aún no esté mapeado.
3. **Normalización** (`03_normalizar_operativo.sql`): lleva la información
   operativa del espejo a las tablas `ope.*` que usa el CRM (cuentas,
   teléfonos, gestiones, promesas, demográficos, datos adicionales, evolución,
   mora/fuente, notas, negociaciones, agenda, bloc, recesos, etc.).
4. **SPs legacy** (`04_sps_legacy.sql`): reimplementa en local el
   comportamiento observable de los SPs legacy usados por Gestión y
   Administración, con los mismos parámetros y columnas de salida capturados
   del aplicativo decompilado.
5. **Verificación** (`05_verificar.sql`): conteos por cartera/tabla, huérfanos,
   duplicados y comparación espejo vs. normalizado.

## Orden de ejecución

```powershell
# 1. Inventario (solo SELECT al remoto)
powershell -NoProfile -ExecutionPolicy Bypass -File .\00_inventario_remoto.ps1

# 2. Generar el DDL del espejo a partir del inventario
powershell -NoProfile -ExecutionPolicy Bypass -File .\01_generar_esquema.ps1

# 3. Crear el esquema y copiar todo
sqlcmd -S localhost -E -C -d BABEL_UNIFICADA -i .\01_esquema_legacy.sql
powershell -NoProfile -ExecutionPolicy Bypass -File .\02_migrar_todo.ps1

# 4. Normalizar a ope.*
sqlcmd -S localhost -E -C -d BABEL_UNIFICADA -i .\03_normalizar_operativo.sql

# 5. Reimplementar SPs legacy
sqlcmd -S localhost -E -C -d BABEL_UNIFICADA -i .\04_sps_legacy.sql

# 6. Verificar
sqlcmd -S localhost -E -C -d BABEL_UNIFICADA -i .\05_verificar.sql
```

## Carpetas y archivos

| Archivo | Uso |
|---|---|
| `00_inventario_remoto.ps1` | Inventario de solo lectura de las 13 bases. |
| `inventario/*.csv` | Salida del inventario (tablas, columnas, claves, módulos). |
| `01_generar_esquema.ps1` | Genera `01_esquema_legacy.sql` desde los CSV. |
| `01_esquema_legacy.sql` | DDL del esquema `legacy` (espejo crudo). |
| `02_migrar_todo.ps1` | Copia masiva de todas las tablas con filas. |
| `03_normalizar_operativo.sql` | Carga de `legacy.*` a `ope.*`. |
| `04_sps_legacy.sql` | SPs equivalentes a los legacy. |
| `05_verificar.sql` | Conteos y validaciones. |
| `99_ejecutar_todo.ps1` | Orquestador opcional. |

## Notas

- El espejo usa tipos "anchos" (`nvarchar(max)`, `decimal(38,x)`, `bigint`,
  `datetime2(7)`) para tolerar diferencias de layout entre carteras sin fallar
  por longitud de BCP.
- Las tablas vacías también se crean en `legacy` para conservar el esquema,
  pero no se copian filas.
- `mig.ControlCarga` registra cada tabla/cartera copiada.
- No se tocan pantallas ni validaciones del CRM; esta carpeta es solo base de
  datos.
