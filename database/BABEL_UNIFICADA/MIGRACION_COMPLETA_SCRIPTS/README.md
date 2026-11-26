# Scripts de migración completa BABEL -> BABEL_UNIFICADA

Carpeta con los scripts usados para la migración total (espejo legacy + normalización + compatibilidad SP + post-carga).

## Orden recomendado

1. `00_inventario_remoto.ps1` - Inventario remoto (solo `SELECT`) de 13 carteras; genera CSVs en `inventario/`.
2. `01_generar_esquema.ps1` - Genera `01_esquema_legacy.sql` desde inventario.
3. `01_esquema_legacy.sql` - Crea esquema `legacy.*` en `BABEL_UNIFICADA`.
4. `02_migrar_todo.ps1` - Copia masiva remota -> `legacy.*` (resumible, 0 writes remotos).
5. `06_cuentas_stub_historicas.sql` - Crea cuentas stub `Activo=0` para controles históricos HIEC/NEMF sin NECU; ajusta `USP_CONSULTA_CUENTAS` a `Activo=1`.
6. `03_normalizar_operativo.sql` - Normaliza `legacy.*` -> `ope.*` (idempotente por `IdRegistroLegacy+IdCartera` donde aplica).
7. `04_sps_legacy.sql` - Capa compatibilidad SPs legacy clave (parcial; ampliar según `MDL_CONSULTAS.cs`).
8. `20_rh_unificar_empleados.sql` - Unifica empleados (`IdEmpleadoUnificado`); ejecutar con `-v SIMULAR=0`.
9. `18_seg_provisionar_usuarios.ps1` - Crea usuarios `seg.Usuario` para empleados activos sin usuario. **Requiere** `-ContrasenaTemporal` o `-Simular`. No inventar contraseña.
10. `05_verificar.sql` - Conteos y huérfanos básicos.

`99_ejecutar_todo.ps1` orquesta el flujo (ajustado para esta carpeta).

## Reglas / notas

- **Remoto `10.80.5.189`: SOLO `SELECT`**. Nunca writes/backups/schema changes. No imprimir/persistir credenciales de `BABELGESTION.xml`.
- **Mapeo empleados:** `ISNULL(rh.Empleado.IdEmpleadoUnificado, rh.Empleado.IdEmpleado)`.
- **Stubs históricos:** `06` crea ~1.42M cuentas `Activo=0` `HISTORICO_SIN_NECU` para ligar HIEC/NEMF sin cuenta NECU. No deben aparecer en consultas normales (filtro `Activo=1`).
- **Hallazgos conocidos:** `NECU_ID_EMPLEADO_ASIGNADO` viene en 0 en legacy; `11_mig` usó `NECU_ID_EMPLEADO`. NETMSYST_DEMO tiene cuentas idénticas a CONCREDITO (decidir excluir/inactivar). SANBORNS/LSF sin NECU en origen.
- **Post-carga:** ejecutar 20 con `SIMULAR=0` y luego 18 tras cada carga relevante.

## Ejecución manual rápida

```powershell
# desde esta carpeta
powershell -NoProfile -ExecutionPolicy Bypass -File .\00_inventario_remoto.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\01_generar_esquema.ps1
sqlcmd -S localhost -E -C -d BABEL_UNIFICADA -b -i .\01_esquema_legacy.sql
powershell -NoProfile -ExecutionPolicy Bypass -File .\02_migrar_todo.ps1
sqlcmd -S localhost -E -C -d BABEL_UNIFICADA -b -i .\06_cuentas_stub_historicas.sql
sqlcmd -S localhost -E -C -d BABEL_UNIFICADA -b -i .\03_normalizar_operativo.sql
sqlcmd -S localhost -E -C -d BABEL_UNIFICADA -b -I -i .\04_sps_legacy.sql
sqlcmd -S localhost -E -C -d BABEL_UNIFICADA -b -v SIMULAR=0 -i .\20_rh_unificar_empleados.sql
powershell -NoProfile -ExecutionPolicy Bypass -File .\18_seg_provisionar_usuarios.ps1 -ContrasenaTemporal '<TEMPORAL>' # o -Simular
sqlcmd -S localhost -E -C -d BABEL_UNIFICADA -b -i .\05_verificar.sql
```
