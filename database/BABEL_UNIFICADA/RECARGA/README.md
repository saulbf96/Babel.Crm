# Recarga de datos operativos de BABEL_UNIFICADA

Carpeta con los scripts para, en otro momento, **vaciar lo operativo y volver a traer
los datos más actuales desde 10.80.5.189**. Todo se ejecuta en `localhost`; en el
servidor remoto **solo se hacen `SELECT`** (nunca `BACKUP`, `INSERT`, `UPDATE` ni
`DELETE`). De nuevo: esto **no inicia ni detiene servidores**; después hacés F5 en la
app, Ctrl+F5 y relogin.

## Archivos

| Archivo | Para qué sirve |
| --- | --- |
| `00_BACKUP_LOCAL.sql` | Backup local opcional, antes de borrar. |
| `01_TRUNCATE_OPERATIVO.sql` | TRUNCATE de `ope.*`, `mig.Stg*` y `mig.ControlCarga`. |
| `02_RECARGA_COMPLETA.ps1` | Todo en uno: backup opcional → TRUNCATE → migración → verificación. |
| `03_VERIFICAR_RECARGA.sql` | Conteos, cargas y estado de integridad después de recargar. |

## Uso recomendado (todo en uno)

Desde `C:\Users\sbasilio\source\repos\Babel.Crm`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File database\BABEL_UNIFICADA\RECARGA\02_RECARGA_COMPLETA.ps1 -ConBackup
```

Sin backup, quitá `-ConBackup`. El log queda en
`%TEMP%\opencode\recarga_completa_yyyyMMdd_HHmmss.log`.

Si hay error, el wrapper se detiene y **no deja la base a medias**: revisá el log,
corregí y volvé a correr el mismo comando (el TRUNCATE deja todo limpio otra vez).

## Paso a paso (si querés controlar cada etapa)

```powershell
sqlcmd -S localhost -E -C -d master          -b -i database\BABEL_UNIFICADA\RECARGA\00_BACKUP_LOCAL.sql
sqlcmd -S localhost -E -C -d BABEL_UNIFICADA -b -i database\BABEL_UNIFICADA\RECARGA\01_TRUNCATE_OPERATIVO.sql
powershell -NoProfile -ExecutionPolicy Bypass -File database\BABEL_UNIFICADA\11_mig_operativo_completo.ps1
sqlcmd -S localhost -E -C -d BABEL_UNIFICADA -b -i database\BABEL_UNIFICADA\RECARGA\03_VERIFICAR_RECARGA.sql
```

Después: **F5 → Ctrl+F5 → relogin con `GESTOR / Babel2026!`** y probar `/asesor` y
los 10 submenús.

## Qué se borra y qué NO

**Se borra:** todas las tablas `ope.*` (cuentas, teléfonos, gestiones, promesas,
demográficos, notas, bloc de notas, recesos, agenda de llamadas, negociaciones,
datos de cuenta, evolución y mora/fuente de ingreso), los staging `mig.Stg*` y todo
el historial de `mig.ControlCarga`.

> Ojo: si en el CRM se capturaron notas, recesos, agenda o negociaciones, esta
> recarga también las borra. El backup local es la única copia de ese contenido.

**NO se toca:** `seg` (usuarios y contraseñas, incluido `GESTOR`), `rh` (empleados),
`cart` (carteras y asignaciones), `cat` (catálogos), `adm` y `log`. Por eso **no hay
que recrear usuarios ni carteras**.

## Si pensás hacer `TRUNCATE` manual de "todas" las tablas

Usá **solo** `01_TRUNCATE_OPERATIVO.sql`. No hagas `TRUNCATE` de `seg`, `rh`, `cart`,
`cat`, `adm` ni `log`: ahí están los usuarios, el hash de contraseñas, los empleados
y las 13 carteras. Si las truncás, la migración no encuentra carteras ni empleados y
hay que reconstruir la base con `01..09`, `12_herramientas.sql` y recrear `GESTOR`
(ese usuario no tiene script automático de creación).

## Resultado esperado

En la corrida del 2026-11-25 dieron: 435,760 cuentas, 904,915 teléfonos, 237,605
gestiones, 20,881 promesas y 318,365 demográficos; 101 cargas `TERMINADA` y 0
`INICIADA`. Las carteras 11 `SANBORNS` y 13 `LSF_PRESTAMOS_PERSONALES` están vacías
también en el legacy (`NECU_DATOSCUENTA` = 0), así que es correcto que sigan en 0.
En una recarga futura las cifras pueden cambiar si el legacy cambió; lo importante
es que no quede ninguna carga `INICIADA`.
