# Memoria de continuidad — BABEL_UNIFICADA / Babel.Crm

> **Última actualización:** 2026-11-25
> **Rama de trabajo:** `feat/unificador_babel` (repositorio `C:\Users\sbasilio\source\repos\Babel.Crm`)
> **Estado:** trabajo en curso, **sin commits**. Todo está en el working tree.
> **Regla:** no hacer commit hasta que el usuario pruebe y apruebe.
> **Regla de mantenimiento:** cada cambio importante debe reflejarse en este documento
> (sección 2 y la sección del módulo tocado) antes de continuar.
> **Servidores:** el usuario levanta la aplicación (Visual Studio / `dotnet run`).
> El agente **no** debe iniciar ni dejar corriendo servidores propios; solo indica
> usuario y contraseña de prueba.
>
> **Paso actual (2026-11-25):** los 11 submenús del `MenuStrip` de `FRM_GESTION_CARTERA`
> ya son pantallas **funcionales** con datos reales (antes eran informativas). La migración
> operativa completa de las 13 carteras está **corriendo** (relanzada tras corregir el layout
> variable de `BAZ_MOVILIDAD` y un deadlock del smoke). Administración sigue terminada y
> aprobada. **Sin commit**; el usuario prueba con `GESTOR` / `Babel2026!` (Gestión) y
> `ADMIN` / `Babel2026!` (Administración). Tras la migración: F5 + Ctrl+F5 + relogin.

Este documento existe para poder retomar el proyecto si la conversación se cierra.
Léelo completo antes de tocar la base o el código.

---

## 1. Objetivo

Sustituir las aplicaciones de escritorio **BABEL ADMINISTRATIVO** y **BABEL GESTION**
por el CRM web `Babel.Crm`, usando **una sola base de datos local unificada** llamada
`BABEL_UNIFICADA`.

El alcance inmediato son las cinco pantallas de Administración:

1. Consulta de empleados
2. Cambia cartera
3. Alta de empleados
4. Asignar personal a cartera
5. Carga de asignaciones

Después sigue **Gestión**. La migración de datos legacy se hará al final y **solo**
con los datos que el personal confirme que se necesitan; no se migra todo.

### Requisitos acordados

- Trabajar solo en `feat/unificador_babel`; sin commits hasta aprobar.
- La base nueva debe estar limpia (sin datos operativos), separada de las bases legacy.
  Solo catálogos y un usuario ADMIN de arranque.
- Una sola base con `IdCartera` en las tablas de negocio; **no** una base por cartera.
- Paridad funcional con el `.exe`: mismos procedimientos/comportamientos legacy.
- Se autorizó borrar cosas obsoletas en esta rama.
- Dejar un usuario de prueba.
- Dejar esta memoria de continuidad.

---

## 2. Estado actual (resumen)

### Hecho

- Se decompilaron ambas apps y se mapearon módulos, formularios, 294 llamadas a SPs
  y 24 bases referenciadas.
- Se confirmó que los SPs remotos están cifrados y que el SQL local es sysadmin.
- Se descifró `BABELGESTION.XML` y se mapearon las 13 carteras activas.
- Se verificó que las 13 bases de cartera comparten el mismo esquema
  (~98–99 tablas, 11 vistas, 29 SPs, 9 funciones).
- Se restauraron localmente con datos: `CONFIGURACION_APP`, `ADMINISTRA_APP`,
  `REPORTERIA_APP`, `RHBABEL`, `NETMSYST_DEMO`, `HISTORICO_APP`.
- Se extrajeron firmas, parámetros y columnas de salida de los SPs legacy relevantes.
- Se creó y ejecutó `BABEL_UNIFICADA` con sus 9 scripts (ver sección 3).
- Se verificó el login local: `ADMIN` / `Babel2026!`, cartera inicial 1 (`BANCO_AZTECA`).
- Se conectó el backend a `BABEL_UNIFICADA` y se renombró el concepto
  `Cliente/Base` → `Cartera` en los DTOs y repositorios.
- Se probó el flujo real por HTTPS: login, `/api/sesion` y `/api/empleados`
  (incluyendo un alta temporal y su limpieza).
- Se actualizaron los modelos/servicio/pantalla Angular de empleados.
- Se agregó `IdUsuario` a la sesión (claim `babel:id_usuario`) para validar carteras.
- Se implementó el **backend** de:
  - Catálogos (`GET /api/catalogos`).
  - Alta de empleados (`POST /api/empleados`).
  - Carteras y personal (`GET /api/carteras`, `GET /api/carteras/{id}/personal`).
  - Asignar/restaurar personal (`POST /api/carteras/{id}/asignar`, `POST /api/carteras/restaurar`).
  - Operativo (`GET /api/carteras/operativo`).
  - Cambio de cartera (`POST /api/sesion/cartera`, reemite cookie).
  - Carga de asignaciones en staging (`GET/POST /api/cargas`, `GET /api/cargas/procesos`).
  - Manejo global de errores de SPs/validaciones como HTTP 400.
- Se ajustaron los SPs `cart.USP_CONSULTA_PERSONAL`, `cart.USP_VALIDA_CARTERA`,
  `cart.USP_CONSULTA_OPERATIVO` y se agregó `adm.USP_AGREGA_DETALLE_LOTE`.
- Backend compila sin errores (`dotnet build`).
- Se implementaron en **Angular** las pantallas:
  - Alta de empleados (`/administracion/alta-empleados`): sin selector de cartera,
    muestra la cartera activa de la sesión y exige apellido materno.
  - Asignar personal (`/administracion/asignar-personal`).
  - Cambia cartera (`/administracion/cambiar-cartera`).
  - Carga de asignaciones (`/administracion/carga-asignaciones`).
- Se agregaron modelos y servicios Angular de catálogos, carteras y cargas.
- Las pantallas de Administración se cargan de forma diferida (lazy); el bundle inicial
  quedó en ~712 kB, sin warnings de presupuesto.
- Se corrigió un bug de validación: en los `record` de request las anotaciones deben ir
  en los parámetros del constructor, no con `[property: ...]`; antes el alta devolvía 500.
- Se agregó `AdministracionApiTests`: login ADMIN, sesión, catálogos, carteras, personal,
  operativo, procesos, historial de cargas, cambio de cartera y validaciones 400.
- Se configuró el arranque para que **F5 abra el navegador**: `launchBrowser: true` en
  `launchSettings.json` y redirección en Development de `/` a `SpaProxy:Url`
  (`https://localhost:51276`), para no tener que pegar la URL a mano. **Confirmado por el
  usuario**: abre Chrome en el inicio.
- Se probaron alta, asignación, operativo y restauración reales dentro de una transacción
  con `ROLLBACK`; la base quedó sin datos de prueba.
- El usuario probó las cinco pantallas en la app y confirmó que funcionan.
- **Alta igual a Babel (pendiente 3 cerrado):** se quitó el selector de cartera; el alta
  usa `IUsuarioActual.IdCartera` (la cartera activa de la sesión) y el apellido materno
  pasó a ser obligatorio. `POST /api/empleados` ya no recibe `idCartera`.
- Compilación y pruebas: `dotnet build` OK, 10 unitarias + 6 integración en verde,
  `npm run build` OK. La prueba de integración nueva valida que el alta sin materno da 400.
- Se agregó `ServicioEmpleadosTests`: comprueba que el alta usa `IUsuarioActual.IdCartera`
  (ignora cualquier `idCartera` del cuerpo), normaliza nombres y rechaza el materno vacío
  sin llamar al repositorio.
- Se ejecutó la limpieza de datos de prueba: base en 0 empleados, 0 asignaciones,
  0 operativo, 0 cargas y 0 auditorías.
- **Migración iniciada:** nuevo script `database/BABEL_UNIFICADA/07_mig_control.sql`
  ejecutado con éxito; `mig.ControlCarga` y sus SPs de inicio/fin están creados.
  `99_verificar.sql` sigue en verde.
- **Migración de personal ejecutada (2026-11-25):** `08_mig_personal.sql` corrió con
  `XACT_ABORT` y transacción. Lee **solo** bases locales (`RHBABEL` y
  `CONFIGURACION_APP`); **no se conectó ni escribió en 10.80.5.189**. Resultado:
  586 empleados, 586 carteras activas, 43 accesos multicartera, **0 omitidos** y
  3 filas en `mig.ControlCarga` en estatus `TERMINADA`. `IdEmpleadoLegacy` e
  `IdRegistroLegacy` conservados. Las contraseñas no se migraron.
  Se agregó `cat.Turno` 7 = `NO ESPECIFICADO` para los 2 empleados con turno legacy 0.
  Tras la migración: 10 unitarias + 6 integración en verde y `npm run build` sin errores.
  Estado final verificado: 586 empleados, 586 carteras activas, 43 accesos,
  7 turnos y 3 cargas de control. Sin commits; rama `feat/unificador_babel`.
- **Paridad del Alta verificada con SQL real** (dentro de transacción con `ROLLBACK`):
  `rh.USP_ALTA_EMPLEADO @IdCartera=2` creó el empleado en `BAZ_FRANQUICIA`,
  departamento derivado 15 y materno `TEST`; mensaje “Empleado dado de alta
  correctamente.” Después del rollback la base quedó en 0 empleados.
- **Gestión implementada y verificada (2026-11-25):** backend (`api/gestion`),
  frontend (`/asesor`) y 4 pruebas unitarias nuevas; 14 unitarias + 6 de integración
  en verde, `npm run build` OK y smoke real de los 10 SPs dentro de transacción con
  `ROLLBACK` (0 filas de prueba). `99_verificar.sql` agregó los conteos de `ope.*`.
- **Usuario de prueba para Gestión creado (2026-11-25):** `GESTOR` / `Babel2026!`,
  `IdUsuario=2`, `IdEmpleado=6`, `IdPuesto=17` (perfil `Supervisor`), cartera 1
  (`BANCO_AZTECA`). Se reutilizó el hash PBKDF2 de ADMIN (verificado contra la
  contraseña con PBKDF2-SHA256, 100000 iteraciones). No se migró contraseña legacy.
  ADMIN no sirve para probar Gestión porque tiene `IdEmpleado=NULL` y el alta de
  gestión exige empleado de la sesión.

### En curso / pendiente inmediato

- **Prueba manual pendiente (reanudada 2026-11-25):** el usuario entra con `GESTOR` /
  `Babel2026!` y prueba los 11 submenús y `/asesor` con los datos migrados. La app puede
  estar abierta en VS; hay que reiniciar con F5 y hacer Ctrl+F5 para recargar el bundle,
  además de relogin. El agente no inicia ni detiene servidores.
- **Migración operativa completa (~25 M filas) EN CURSO:** relanzada el 2026-11-25 con
  `$lote = 100000` y log en `%TEMP%\opencode\mig_completa_final.log`. El primer intento
  falló en cartera 3 (`BAZ_MOVILIDAD`) por `NECU_GESTION_DESC`; el script ahora consulta
  `INFORMATION_SCHEMA.COLUMNS` remoto y usa columnas alternas o `NULL`. Smoke de cartera 3
  verificado: 54,747 cuentas y 16 cargas `TERMINADA` (13:45:52). Un segundo smoke con
  `$lote = 1000` murió por deadlock al insertar teléfonos; no quedó proceso corriendo y las
  2 cargas `INICIADA` huérfanas se marcaron `CANCELADA` antes del relanzamiento. Solo
  `SELECT` en `10.80.5.189`; nunca `BACKUP`, `INSERT`, `UPDATE` ni `DELETE` en el remoto.
- `mig.ControlCarga` ya existe y `12_herramientas.sql` quedó aplicado (tablas y SPs de
  Herramientas). Tras la migración hay que verificar conteos por cartera y `ControlCarga`.

### Bloqueado

- `Carga de asignaciones` real depende del SP cifrado
  `PROCESOS_CLIENTES.DBO.PROCESO_ASIGNACION_<base>` y de conocer el layout exacto del
  Excel. El `.exe` copiaba el archivo a `\\10.80.5.189\BANCO AZTECA\ASIGNACIONES\` y
  llamaba ese SP; por ahora solo existen tablas y SPs de staging.
- Faltan por respaldar/restaurar localmente 12 bases de cartera (solo está
  `NETMSYST_DEMO`); se necesitan para la migración completa de datos.
- Conteos legacy locales al 2026-11-25: `RHBABEL.NEEM_EMPLEADO` 586 (el remoto reportó
  585, hay que conciliar), `REBA_BASE_AREA_EMPLEADO` 13, `NEPE_PASSWORD` 586 (**no migrar**).
  `CONFIGURACION_APP.CAPD_PRODUCTO`, `CASE_SEGMENTO` y `CASM_SEGMENTO` tienen 1 fila cada
  uno con ID 0, así que el operativo usa los defaults actuales del CRM.
- El T-SQL de los SPs legacy sigue cifrado; solo se conocen firmas/columnas.

---

## 3. Base de datos `BABEL_UNIFICADA`

### Scripts (ejecutar en este orden)

Carpeta: `database/BABEL_UNIFICADA/`

| Script | Contenido |
|---|---|
| `01_crear_base.sql` | Crea la base, esquemas `seg/rh/cart/ope/adm/cat/log` y bitácora. |
| `02_catalogos.sql` | Puestos (29), departamentos (25), sexos (3), turnos (7, incluye `NO ESPECIFICADO`), clientes (13), carteras (13). |
| `03_rh_empleados.sql` | `rh.Empleado`, `rh.EmpleadoCartera`, `rh.EmpleadoCarteraAcceso`, consulta/alta y catálogos. |
| `04_seg_usuarios.sql` | `seg.Usuario`, login, bloqueo, usuario ADMIN. |
| `05_cart_asignaciones.sql` | Carteras, validación, personal, asignar/restaurar y operativo. |
| `06_adm_carga_asignaciones.sql` | Staging de carga de asignaciones. |
| `07_mig_control.sql` | Esquema `mig`, tabla `ControlCarga` y SPs para iniciar/cerrar cargas. |
| `08_mig_personal.sql` | Migración de empleados, cartera activa y accesos desde bases locales. |
| `09_gestion.sql` | `cat.TipoGestion`, tablas `ope.*` de Gestión y 10 SPs `ope.USP_*`. |
| `10_mig_operativo_muestra.ps1` | Muestra de 150 cuentas de `BANCO_AZTECA` (cartera 1). |
| `11_mig_operativo_completo.ps1` | Migración completa de las 13 carteras activas, por lotes de 100000, con detección de columnas remotas y `mig.ControlCarga`. |
| `12_herramientas.sql` | Tablas y SPs `ope.*` para Notas, Bloc de Notas, Recesos, Agenda, Negociaciones y actualización de demográficos. |
| `99_verificar.sql` | Verificación de conteos, carteras, ADMIN, SPs y pruebas. |

### Cómo ejecutarlos (SQL local, Windows auth)

```powershell
cd C:\Users\sbasilio\source\repos\Babel.Crm
$archivos = @(
  "database\BABEL_UNIFICADA\01_crear_base.sql",
  "database\BABEL_UNIFICADA\02_catalogos.sql",
  "database\BABEL_UNIFICADA\03_rh_empleados.sql",
  "database\BABEL_UNIFICADA\04_seg_usuarios.sql",
  "database\BABEL_UNIFICADA\05_cart_asignaciones.sql",
  "database\BABEL_UNIFICADA\06_adm_carga_asignaciones.sql",
  "database\BABEL_UNIFICADA\07_mig_control.sql",
  "database\BABEL_UNIFICADA\08_mig_personal.sql",
  "database\BABEL_UNIFICADA\99_verificar.sql"
)
foreach ($a in $archivos) {
  Write-Output "`n===== $a ====="
  sqlcmd -S localhost -E -C -b -l 30 -i $a
  if ($LASTEXITCODE -ne 0) { break }
}
```

> Los scripts usan `SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON;` porque hay
> índices filtrados (`UX_Empleado_Legacy`, `UX_EmpleadoCartera_Activa`,
> `UX_AgenteOperativo_Activo`). Si se ejecuta SQL manual sobre esas tablas,
> hay que activar `QUOTED_IDENTIFIER ON` en la sesión.

### Usuarios de prueba

- **Administración:** `ADMIN` / `Babel2026!`
  - `IdPuesto = 1` (Administrador), `IdDepartamento = 12`, `DebeCambiarContrasena = 0`.
- **Gestión:** `GESTOR` / `Babel2026!`
  - `IdUsuario = 2`, `IdEmpleado = 6`, `IdPuesto = 17` (Supervisor), cartera 1 `BANCO_AZTECA`.
  - ADMIN no sirve para gestionar: tiene `IdEmpleado = NULL`.
- Hash PBKDF2-SHA256 en `seg.Usuario`; nunca se guarda en claro ni se migró del legacy.

### Trazabilidad del origen de los datos

Hoy la base solo tiene catálogos sembrados por los scripts y el usuario ADMIN:
13 carteras, 13 clientes, 29 puestos, 25 departamentos, 3 sexos, 6 turnos,
4 procesos y 0 empleados/asignaciones. No hay datos operativos legacy migrados.

Para la migración futura ya existen estas llaves de origen:

| Tabla nueva | Columna | Origen legacy |
|---|---|---|
| `cart.Cartera` | `IdBaseLegacy` | `CABD_BASES_DATOS.CABD_ID_BASE` (15–27) |
| `rh.Empleado` | `IdEmpleadoLegacy` | `NEEM_EMPLEADO.NEEM_ID_EMPLEADO` |
| `rh.EmpleadoCartera` | `IdRegistroLegacy` | `RECE_CLIENTE_EMPLEADO.RECE_ID_GCL_EMPL` |

No existe todavía una tabla de control de migración; `log.Auditoria` es para acciones
del CRM, no para migración. Antes de copiar datos legacy se agregará `mig.ControlCarga`
(o equivalente) con origen, fecha, filas copiadas y usuario.

### Esquemas y tablas principales

- `cat.Sexo`, `cat.Turno`
- `rh.Puesto`, `rh.Departamento`
- `rh.Empleado`, `rh.EmpleadoCartera`, `rh.EmpleadoCarteraAcceso`
- `seg.Usuario`, `log.AccesoBloqueo`, `log.Auditoria`
- `cart.Cliente`, `cart.Cartera`
- `cat.TipoGestion` (7 tipos)
- `ope.AgenteOperativo`
- `ope.Cuenta`, `ope.Telefono`, `ope.Gestion`, `ope.Promesa`, `ope.Demografico`,
  `ope.MoraFuenteIngreso`, `ope.EvolucionCuenta`, `ope.DatoCuenta` (todas con `IdCartera`)
- `adm.ProcesoAsignacion`, `adm.CargaAsignacion`, `adm.CargaAsignacionDetalle`

### SPs nuevos (equivalentes legacy)

| Nuevo | Legacy equivalente |
|---|---|
| `rh.USP_CONSULTA_EMPLEADOS` | `CONSULTA_NEEU_EMPLEADOS_MODULO` |
| `rh.USP_ALTA_EMPLEADO` | `INSERTA_NEEU_EMPLEADOS_MODULO` |
| `rh.USP_CONSULTA_PUESTOS` | catálogo de puestos |
| `rh.USP_CONSULTA_DEPARTAMENTOS` | catálogo de departamentos |
| `rh.USP_CONSULTA_SEXOS` | catálogo de sexos |
| `rh.USP_CONSULTA_TURNOS` | catálogo de turnos |
| `seg.USP_CONSULTA_USUARIO` | `CONSULTA_NEEM_EMPLEADO` (sin contraseña en claro) |
| `seg.USP_DEBE_CAMBIAR` | cambio de contraseña pendiente |
| `seg.USP_BLOQUEAR_USUARIO` | bloqueo por intentos |
| `seg.USP_REGISTRA_ACCESO` | último acceso |
| `cart.USP_CONSULTA_CARTERAS` | carteras visibles para el usuario |
| `cart.USP_VALIDA_CARTERA` | validación de acceso a cartera |
| `cart.USP_CONSULTA_PERSONAL` | personal para asignar |
| `cart.USP_ASIGNA_PERSONAL` | `ACTUALIZA_AGENTE_BASE` + `INSERTA_TRAO_AGENTE_OPERATIVO` |
| `cart.USP_RESTAURA_PERSONAL` | `RESTAURA_AGENTE_BASE` |
| `cart.USP_CONSULTA_OPERATIVO` | `CONSULTA_TRAO_AGENTE_OPERATIVO` |
| `cart.USP_CONSULTA_CLIENTES` | catálogo de clientes |
| `adm.USP_CONSULTA_PROCESOS` | procesos 1–4 de carga |
| `adm.USP_CREA_CARGA` | alta de carga |
| `adm.USP_CONSULTA_CARGAS` | historial de cargas |
| `adm.USP_AGREGA_DETALLE` | detalle de fila |
| `adm.USP_AGREGA_DETALLE_LOTE` | detalle de muchas filas (JSON) |
| `adm.USP_ACTUALIZA_CARGA` | estatus de la carga |
| `ope.USP_CONSULTA_TIPOS_GESTION` | catálogo de tipos de gestión |
| `ope.USP_CONSULTA_CUENTAS` | localizar cuenta de la cartera |
| `ope.USP_CREA_CUENTA` | capturar cuenta (`ID_CONTROL` legacy) |
| `ope.USP_CONSULTA_CUENTA` | detalle de cuenta |
| `ope.USP_CONSULTA_TELEFONOS` / `ope.USP_REGISTRA_TELEFONO` | teléfonos de `NEBT_BASE_TELEFONICA` |
| `ope.USP_CONSULTA_GESTIONES` / `ope.USP_REGISTRA_GESTION` | gestiones de `NEGE_GESTION` |
| `ope.USP_CONSULTA_PROMESAS` / `ope.USP_REGISTRA_PROMESA` | promesas de `NEPR_PROMESAS` |
| `ope.USP_CONSULTA_DEMOGRAFICOS` | demográficos de `NEDE_DEMOGRAFICOS` |
| `ope.USP_CONSULTA_NOTAS` / `ope.USP_REGISTRA_NOTA` | `NENO_NOTAS` (`FRM_NOTAS`) |
| `ope.USP_CONSULTA_BLOCNOTA` / `ope.USP_GUARDA_BLOCNOTA` | bloc del ejecutivo (`FRM_BLOCNOTAS`) |
| `ope.USP_INICIA_RECESO` / `ope.USP_FINALIZA_RECESO` / `ope.USP_CONSULTA_RECESOS` | `HIRE_RECESO` / `NEPG_RECESOS` (`FRM_BLOQUEAR`) |
| `ope.USP_CONSULTA_AGENDA` / `ope.USP_REGISTRA_AGENDA` / `ope.USP_CAMBIA_ESTATUS_AGENDA` | agenda de llamadas (habilitada en el CRM) |
| `ope.USP_CONSULTA_NEGOCIACIONES` / `ope.USP_REGISTRA_NEGOCIACION` | `NENE_NEGOCIACIONES` (`Calculadora`) |
| `ope.USP_ACTUALIZA_DEMOGRAFICO` | `NEDE_DEMOGRAFICOS` (`Actualiza Información`) |

---

## 4. Mapeo legacy → nuevo

### Carteras

`IdCartera` nuevo = `CART_CARTERA` legacy; `IdBaseLegacy` = `CABD_BASES_DATOS`.

| IdCartera | IdBaseLegacy | Nombre | Departamento |
|---:|---:|---|---:|
| 1 | 15 | BANCO_AZTECA | 14 |
| 2 | 16 | BAZ_FRANQUICIA | 15 |
| 3 | 17 | BAZ_MOVILIDAD | 16 |
| 4 | 18 | NETMSYST_DEMO | NULL → fallback 12 |
| 5 | 19 | MBA | 17 |
| 6 | 20 | KUBO | 18 |
| 7 | 21 | BAZ_EXEMPLEADOS | 19 |
| 8 | 22 | TOTAL_PLAY | 20 |
| 9 | 23 | CONCREDITO | 21 |
| 10 | 24 | SEARS | 22 |
| 11 | 25 | SANBORNS | 23 |
| 12 | 26 | INBURSA_FIANZAS_TELCEL | 28 |
| 13 | 27 | LSF_PRESTAMOS_PERSONALES | 29 |

### Decisiones de migración

- **Sexo:** el `FRM_ALTAEMPLEADOS` del `.exe` guarda `Conversion.Val(CMB_SEXO.Text)`,
  es decir 2=MASCULINO, 3=FEMENINO, 4=OTRO. `CASX_SEXO` etiqueta 1=MASCULINO,
  2=FEMENINO (código viejo, solo 3 filas de ejemplo). Mapeo aplicado:
  legacy 1 y 2 → CRM 1 (MASCULINO), legacy 3 → CRM 2 (FEMENINO),
  legacy 4 y 0 → CRM 3 (OTRO; 0 viene en blanco). Comprobado con los datos:
  el grupo legacy 3 contiene nombres femeninos de forma consistente. Queda
  documentada la ambigüedad del código 2 (nombres mezclados en los datos legacy).
- **Turno:** el mismo formulario guarda 1=Matutino, 2=Vespertino, 3=Completo,
  idénticos al CRM. Legacy 0 (2 empleados) → CRM 7 `NO ESPECIFICADO` (nuevo).
- **Cartera del empleado:** `CONFIGURACION_APP.RECE_CLIENTE_EMPLEADO` (586 filas) es
  la fuente real, no `RHBABEL.REBA_BASE_AREA_EMPLEADO` (solo 13 filas del empleado 1).
  Si `RECE_ID_CARTERA` no está entre 1 y 13 se deriva de `RECE_ID_BASE` vía
  `cart.Cartera.IdBaseLegacy`; los accesos múltiples salen de
  `REUM_USUARIO_MULTI_CARTERA` (43 filas).
- **Contraseñas:** `CONSULTA_NEEU_EMPLEADOS_MODULO` devuelve la contraseña en claro.
  **No se migran**. El CRM usa PBKDF2.
- **Cambia Cartera:** en el `.exe` solo cambiaba `MDL_INICIO.ID_BBDD` en la sesión.
  En web se reemite la cookie con la nueva cartera; no escribe en la base.
- **Asignar personal:** el `.exe` mueve una sola cartera activa por empleado
  (`ACTUALIZA_AGENTE_BASE`) y opcionalmente registra operativo
  (`INSERTA_TRAO_AGENTE_OPERATIVO`). El nuevo `cart.USP_ASIGNA_PERSONAL` hace lo mismo:
  cierra la asignación anterior, inserta la nueva, actualiza accesos y, si
  `@Operativo = 1`, registra en `ope.AgenteOperativo`.
- **Bases:** no se crea una base por cartera. Todo vive en `BABEL_UNIFICADA` con
  `IdCartera`.

### Llaves legacy (solo referencia; no usar en el CRM)

- `MDL_INICIO.EMPATAR = "(+ay|g15<1:+3!H"`
- `EMPATARRH = "KCtheXxnMTU8MTorMyFI"`

---

## 5. Backend (.NET)

### Cambios ya aplicados

- `UnoContact.Crm.Infrastructure/Identidad/RepositorioUsuariosCrm.cs`
  - Usa `BABEL_UNIFICADA.seg.USP_CONSULTA_USUARIO`.
  - Devuelve `UsuarioCrm` con `IdCartera`/`Cartera`.
- `UnoContact.Crm.Application/Acceso/IRepositorioUsuarios.cs`
  - `UsuarioCrm(int IdUsuario, int IdEmpleado, string Usuario, short IdPuesto, short IdArea,
    bool Bloqueado, bool Activo, short IdCartera, string Cartera)`.
  - `IdUsuario` se agregó para poder validar carteras permitidas con
    `cart.USP_CONSULTA_CARTERAS @IdUsuario`.
- `UnoContact.Crm.Application/Rh/EmpleadoResumen.cs`
  - DTO de paridad con la consulta legacy y `FiltroEmpleados` con `IdCartera`.
- `UnoContact.Crm.Application/Rh/AltaEmpleado.cs`
  - `SolicitudAltaEmpleado` ya no incluye `IdCartera`; `Materno` es obligatorio.
- `UnoContact.Crm.Application/Rh/ServicioEmpleados.cs`
  - El alta toma la cartera de `IUsuarioActual.IdCartera` y valida nombre, paterno y materno.
- `UnoContact.Crm.Infrastructure/Rh/RepositorioEmpleados.cs`
  - Llama `BABEL_UNIFICADA.rh.USP_CONSULTA_EMPLEADOS` y mapea todos los campos.
  - `AltaAsync` recibe `idCartera` por separado (ya no viene del request).
- `UnoContact.Crm.Server/Controllers/EmpleadosController.cs`
  - Recibe `idCartera` (no `idCliente`).
- `UnoContact.Crm.Server/Controllers/AccesoController.cs`
  - Claims: `babel:id_usuario`, `babel:id_cartera` y `babel:cartera`
    (ya no `id_base_datos`).
- `UnoContact.Crm.Infrastructure/Identidad/UsuarioActualCookie.cs`
  - Expone `IdUsuario`, `IdCartera` y `Cartera` desde la cookie.
- `UnoContact.Crm.Application/Abstracciones/IUsuarioActual.cs`
  - Agrega `IdUsuario`, `IdCartera` y `Cartera`.
- `UnoContact.Crm.Application/Sesion/ServicioSesion.cs`
  - `SesionDto` ahora incluye `IdCartera` y `Cartera`.
- Pruebas unitarias actualizadas (`ServicioAccesoTests`).

### Cadena de conexión

Los user secrets del proyecto `UnoContact.Crm.Server` ya apuntan a la base nueva:

```powershell
cd C:\Users\sbasilio\source\repos\Babel.Crm\UnoContact.Crm.Server
dotnet user-secrets set "ConnectionStrings:UnoContact" "Server=localhost;Database=BABEL_UNIFICADA;Integrated Security=True;TrustServerCertificate=True"
dotnet user-secrets set "ConnectionStrings:Babel" "Server=localhost;Database=BABEL_UNIFICADA;Integrated Security=True;TrustServerCertificate=True"
```

`UnoContact.Crm.Infrastructure.DependencyInjection.NombreCadenaConexion = "UnoContact"`.

### Cómo compilar, probar y levantar

```powershell
cd C:\Users\sbasilio\source\repos\Babel.Crm

# Compilar
dotnet build UnoContact.Crm.slnx --nologo -v minimal

# Pruebas unitarias
dotnet test tests\UnoContact.Crm.UnitTests\UnoContact.Crm.UnitTests.csproj --no-build --nologo -v minimal

# Pruebas de integración (requieren BABEL_UNIFICADA y el usuario ADMIN)
dotnet test tests\UnoContact.Crm.IntegrationTests\UnoContact.Crm.IntegrationTests.csproj --nologo -v minimal

# Cliente Angular
cd uno-contact-crm.client
npm run build

# Levantar API (HTTPS obligatorio por la cookie __Host-)
$env:ASPNETCORE_ENVIRONMENT="Development"
dotnet run --project UnoContact.Crm.Server --no-build --no-launch-profile --urls "https://localhost:7263;http://localhost:5018"
```

### Prueba manual del flujo (curl)

La API exige el encabezado `X-UnoContact-Crm` en todo POST/PUT/DELETE (protección CSRF)
y la cookie `__Host-UnoContactCrm` solo viaja por HTTPS.

```powershell
$cookie = Join-Path $env:TEMP "babel_cookies.txt"
if (Test-Path $cookie) { Remove-Item $cookie }

curl.exe -k -s -c $cookie -H "Content-Type: application/json" -H "X-UnoContact-Crm: 1" `
  -d '{\"usuario\":\"ADMIN\",\"contrasena\":\"Babel2026!\"}' `
  https://localhost:7263/api/acceso/iniciar

curl.exe -k -s -b $cookie https://localhost:7263/api/sesion
curl.exe -k -s -b $cookie "https://localhost:7263/api/empleados"
```

Resultado esperado del login: `{"debeCambiarContrasena":false}`.
`/api/sesion` debe devolver `idCartera:1` y `cartera:"BANCO_AZTECA"`.

### Endpoints existentes

- `POST /api/acceso/iniciar` — login.
- `POST /api/acceso/cerrar` — logout.
- `GET /api/sesion` — usuario, cartera, perfiles y menú.
- `POST /api/sesion/cartera` — valida y cambia la cartera de la sesión (cookie).
- `GET /api/catalogos` — carteras, puestos, departamentos, sexos y turnos.
- `GET /api/empleados?idCartera=&nombre=&idPuesto=&soloActivos=` — consulta.
- `POST /api/empleados` — alta de empleado.
- `GET /api/carteras` — carteras permitidas.
- `GET /api/carteras/{idCartera}/personal?texto=` — personal para asignar.
- `POST /api/carteras/{idCartera}/asignar` — asigna/mueve personal.
- `POST /api/carteras/restaurar` — restaura personal de operativo.
- `GET /api/carteras/operativo?idEmpleado=&idCartera=` — personal operativo.
- `GET /api/cargas/procesos` — procesos 1–4.
- `GET /api/cargas?idCartera=` — historial de cargas.
- `POST /api/cargas` — registra una carga en staging.
- `GET /api/gestion/cuentas`, `GET/POST /api/gestion/cuenta`, teléfonos, gestiones,
  promesas, demográficos y catálogo de tipos — política `Gestion`; cartera y empleado
  siempre vienen de la sesión.
- `GET/POST /api/herramientas/notas/{idCuenta}`, `GET/PUT /api/herramientas/bloc-nota`,
  `GET/POST /api/herramientas/recesos`, `POST /api/herramientas/recesos/{id}/fin`,
  `GET/POST /api/herramientas/agenda`, `POST /api/herramientas/agenda/{id}/estatus`,
  `GET/POST /api/herramientas/negociaciones/{idCuenta}`,
  `PUT /api/herramientas/demograficos/{idCuenta}` — política `Gestion`.
- `GET /api/salud` — health check anónimo.

---

## 6. Frontend (Angular)

Ruta del cliente: `uno-contact-crm.client/`.

### Cambios ya aplicados

- `src/app/core/empleados/empleados.models.ts`
  - Modelo nuevo: `usuario`, `idCartera`, `cartera`, `idSexo`, `sexo`,
    `idTurno`, `turno`, `curp`, `nss`, `fechaRegistro`, etc.
  - `FiltroEmpleados` usa `idCartera`.
- `src/app/core/empleados/empleados.service.ts`
  - Envía `idCartera`.
- `src/app/features/empleados/empleados.ts` y `.html`
  - Columnas: ID, usuario, nombre, puesto, departamento, cartera, turno,
    ingreso y estatus.
- `src/app/core/sesion/sesion.models.ts` y `sesion.service.ts`
  - `Sesion` incluye `idCartera` y `cartera`; hay un `computed` `cartera`.
- `src/app/layout/shell.html`
  - La barra superior muestra `usuario · cartera`.
- Modelos y servicios nuevos:
  - `core/catalogos/catalogos.models.ts` y `catalogos.service.ts`.
  - `core/carteras/carteras.models.ts` y `carteras.service.ts`.
  - `core/cargas/cargas.models.ts` y `cargas.service.ts`.
  - `core/empleados`: alta de empleado agregada a modelos y servicio.
  - `core/sesion/sesion.service.ts`: `cambiarCartera()` reemite la cookie.
- Pantallas nuevas:
  - `features/alta-empleados/` — formulario con cartera, puesto, sexo, turno y nombres.
  - `features/asignar-personal/` — búsqueda, selección múltiple, operativo y restaurar.
  - `features/cambiar-cartera/` — lista de carteras y cambio de sesión.
  - `features/carga-asignaciones/` — selección de proceso/archivo e historial (staging).
- `app.routes.ts`: las cinco pantallas de Administración usan `loadComponent`
  (carga diferida) y `perfilGuard('Administrador')`.

### Cómo correr el cliente

```powershell
cd C:\Users\sbasilio\source\repos\Babel.Crm\uno-contact-crm.client
npm install
npm start
```

El `SpaProxy` de Visual Studio normalmente levanta Angular y el API juntos.
Para probar solo el API, usar los comandos de la sección 5.

### Flujo de prueba manual de Administración

Requisitos: SQL local con `BABEL_UNIFICADA` (scripts 01–06), user secrets apuntando a
esa base y la app levantada por el usuario. Login: `ADMIN` / `Babel2026!`.

1. **Login y sesión**
   - Entrar a la URL de Angular y autenticarse.
   - Verificar barra superior: `ADMIN · BANCO_AZTECA`.
   - El menú debe mostrar Inicio y las cinco pantallas de Administración.

2. **Consulta de empleados**
   - Al inicio debe salir vacía (0 empleados).
   - Probar búsqueda por nombre y el check “Solo activos”.

3. **Alta de empleados**
   - Debe mostrar la **cartera activa** de la sesión; ya no hay selector de cartera.
   - Capturar puesto, sexo, turno, nombre, apellido paterno y **apellido materno**.
   - Esperar mensaje “Empleado dado de alta correctamente” con su ID.
   - Buscarlo en Consulta: debe aparecer con la cartera activa y el departamento derivado.
   - Dejar el materno vacío: debe salir “Ingresa el apellido materno”, no error 500.
   - Para dar de alta en otra cartera, cambiarla antes en “Cambia cartera”.

4. **Cambia cartera**
   - La cartera actual debe estar marcada como “Actual”.
   - Entrar a otra cartera: cambia la barra superior y no mueve empleados.
   - Regresar a `BANCO_AZTECA`.

5. **Asignar personal**
   - Elegir cartera destino y buscar al empleado de prueba.
   - Seleccionarlo, marcar “Registrar en operativo” y asignar.
   - Esperar “Asignados: 1. Omitidos: 0”; la fila debe mostrar “En esta cartera”
     y “Operativo”.
   - En Consulta, el empleado debe aparecer en la cartera destino.
   - Probar “Restaurar operativo”: quita el operativo, no la cartera.
   - Probar selección múltiple y “Seleccionar todos”.

6. **Carga de asignaciones (staging)**
   - Elegir cartera, proceso (1–4) y un archivo CSV/TXT (o Excel).
   - CSV/TXT muestran el número de filas leídas; Excel solo registra el nombre.
   - Al registrar: mensaje “Carga recibida. Pendiente de validación.” e historial
     con estatus `RECIBIDA`, usuario `ADMIN` y fecha.
   - **No procesa asignaciones todavía**: el SP legacy está cifrado.

7. **Cierre**
   - Probar “Cerrar sesión” y volver a entrar.
   - Si se usaron datos de prueba, limpiarlos antes de migrar (ver sección 11).

---

## 7. Pendientes inmediatos (en orden sugerido)

1. ~~**Probar Administración en la app**~~ — **hecho y confirmado por el usuario**.
   - Login `ADMIN` / `Babel2026!`; las cinco pantallas funcionan y F5 abre Chrome.

2. **Retestar el Alta (paridad aplicada)**
   - **Verificación automática lista:** `ServicioEmpleadosTests` confirma que se usa la
     cartera de la sesión y que el materno vacío se rechaza antes de tocar la base.
   - **Verificación SQL real lista:** alta con cartera 2 → `BAZ_FRANQUICIA`, depto 15,
     materno guardado; `ROLLBACK` dejó la base limpia.
   - **Confirmación visual del usuario recibida (2026-11-25):** Alto cerrada; no hay
     selector de cartera, se muestra la cartera activa y el materno es obligatorio.

3. ~~**Limpieza de datos de prueba**~~ — **hecha**.
   - Se borraron empleado 2 (`karla perez perez`), 2 asignaciones, 1 acceso,
     1 carga y 3 auditorías. Conteos finales: todo en 0 (SQL en la sección 11).

4. **Migración legacy — personal local migrado**
   - **Hecho:** `07_mig_control.sql` creó `mig.ControlCarga` y sus SPs de inicio/fin.
   - **Hecho:** `08_mig_personal.sql` ejecutado: 586 empleados, 586 carteras activas,
     43 accesos multicartera, 0 omitidos, 3 cargas `TERMINADA` en `mig.ControlCarga`.
     Lee solo tablas locales; **sin conexión ni escritura en 10.80.5.189**.
   - **Hecho:** segmento/producto/campaña se copiaron de `RECE_CLIENTE_EMPLEADO`
     (los 586 registros traen 0, igual que los defaults del CRM).
   - **Hecho:** contraseñas excluidas; el CRM usa PBKDF2.
   - **Inventario remoto de solo lectura (2026-11-25):** se conectó a `10.80.5.189`
     únicamente con `SELECT` a `sys.databases`, `sys.tables` y `sys.partitions`;
     **sin BACKUP, INSERT, UPDATE ni DELETE**. Las 13 bases de cartera están online
     y comparten ~98 tablas idénticas. Contienen datos operativos de Gestión
     (aprox. 25 millones de filas en total): `NEBT_BASE_TELEFONICA`, `NEGE_GESTION`,
     `NEDE_DEMOGRAFICOS`, `HIEC_EVOLUCION_CUENTA`, `NECU_DATOSCUENTA`,
     `NEPR_PROMESAS`, etc. `BAZ_MOVILIDAD` sola supera los 12 M de filas en
     `NEBT_BASE_TELEFONICA`. **No hay tablas destino en `BABEL_UNIFICADA` para esos
     datos** (solo `ope.AgenteOperativo`): copiarlos requiere primero diseñar el
     esquema de Gestión, que es la fase siguiente.
   - **Conciliación cerrada (2026-11-25, solo lectura):** el remoto `RHBABEL.dbo.NEEM_EMPLEADO`
     tiene 586 registros y 586 activos (el 585 previo era un dato stale), y la lista de
     `NEEM_ID_EMPLEADO` activos coincide exactamente con los 586 `IdEmpleadoLegacy`
     migrados: 0 IDs solo en remoto y 0 solo en local. No hubo escrituras en el 189.

5. **Gestión — lista para prueba manual**
   - Usuario: `GESTOR` / `Babel2026!` (perfil `Supervisor`, cartera `BANCO_AZTECA`).
   - Ruta: `/asesor` (menú “Gestión de cartera”). Ver flujo completo en la sección 8.
   - Después del visto bueno: migrar los ~25 M de filas operativas.

6. **Carga real de asignaciones** (bloqueada)
   - Confirmar el layout del Excel y el SP `PROCESO_ASIGNACION_<base>` con sistemas.
   - Mientras tanto, la pantalla solo registra staging e historial.

7. **Cierre de Administración**
   - Actualizar esta memoria tras cada cambio.
   - No hacer commit hasta que el usuario apruebe la prueba completa.

---

## 8. Después de Administración: Gestión

- Revisar `decompiled/BABELGESTION/` y el XML `analysis/BABELGESTION.xml`.
- Mapear pantallas de Gestión a `ope.*` y `cart.*`.
- La migración de datos legacy se hace al final, solo con lo que el personal confirme.
- Ya no hace falta restaurar las 12 bases: se puede inventariar y leer `10.80.5.189`
  con `SELECT` directo, sin modificar el servidor (ver sección 7).
- **Inventario agregado de tablas con datos (solo lectura, 2026-11-25):**
  las 31 tablas con filas suman ~25 M. Las mayores son `NEBT_BASE_TELEFONICA`
  (14,744,596 en 11 bases), `NEGE_GESTION` (3,432,964 en 8), `NEDE_DEMOGRAFICOS`
  (3,098,378 en 11), `HIEC_EVOLUCION_CUENTA` (2,335,008 en 9),
  `NEIG_ID_GES_ID_GPO_STA` (1,607,964 en 1), `NEMF_MORA_FUENTE_INGRESO`
  (1,115,108 en 7) y `NEPR_PROMESAS` (1,105,100 en 7).
- **Tablas pequeñas/control:** `CARM_RAZON_MORA` (216), `CAFI_FUENTE_INGRESO`
  (81), `CADP_DONDE_PAGO` (26), `CARN_RAZON_NO_DEL_PAGO` (26),
  `NENE_NEGOCIACIONES` (26), `REES_STA_SIT_FILA_TRABAJO` (3),
  `NEFT_FILAS_TRABAJO` (3) y `NEEA_EMPLEADO_ASIGNADO` (2). Ninguna tiene tabla
  destino equivalente en `BABEL_UNIFICADA`. En particular, las 2 filas de
  `NEEA_EMPLEADO_ASIGNADO` (KUBO/base 20 y NETMSYST_DEMO/base 18) asignan
  `NEEA_ID_EMPLEADO=1` a `NEEA_ID_FILA_TRABAJO=1`; son asignaciones operativas
  de fila de trabajo, **no** accesos de empleado a cartera, así que no se copian
  a `rh.EmpleadoCarteraAcceso`.
- **Conclusión:** el alcance migrable con el esquema actual quedó cerrado
  (empleados, carteras activas, accesos y control de cargas). La copia de los
  ~25 M de filas operativas requiere primero diseñar el esquema de Gestión en
  `ope.*`/`cart.*`; no se hace en esta fase ni se inventan tablas destino.

- **Verificación final (2026-11-25):** `99_verificar.sql` terminó correctamente;
  `dotnet build` 0 errores, 10 pruebas unitarias y 6 de integración en verde;
  `npm run build` en verde. Sin servidores levantados por el agente y sin commit.
- **Inicio de Gestión aprobado por el usuario (2026-11-25):** se implementará
  primero el módulo/esquema de Gestión; se avisará al usuario para pruebas
  manuales y solo después se ejecutará la migración de los ~25 M de filas.
- **Paso 1 de Gestión hecho:** nuevo script `09_gestion.sql` creado y ejecutado
  en `BABEL_UNIFICADA`: `cat.TipoGestion` (7 tipos), `ope.Cuenta`, `ope.Telefono`,
  `ope.Gestion`, `ope.Promesa`, `ope.Demografico`, `ope.MoraFuenteIngreso`,
  `ope.EvolucionCuenta` y `ope.DatoCuenta`, todas con `IdCartera` e `IdRegistroLegacy`
  cuando aplica, más 10 SPs `ope.USP_*`. No se tocó el 189 ni se borraron objetos.
- **Paso 2 de Gestión hecho (backend):** DTOs/contratos en
  `UnoContact.Crm.Application/Gestion/`, `ServicioGestion` (toma cartera y empleado de
  `IUsuarioActual`, nunca del cliente), `RepositorioGestion` (SPs parametrizados),
  `GestionController` (`api/gestion`), DI en Application/Infrastructure y política
  `Gestion` para `Asesor`, `Supervisor` y `Administrador`. El alta usa `ID_CONTROL`
  legacy como control operativo; `CUENTA` es solo el número visible.
- **Paso 3 de Gestión hecho (frontend):** `core/gestion/` (models + service) y
  `features/gestion/` (pantalla). La ruta `/asesor` reemplaza a `EnConstruccion` y carga
  el componente de forma diferida; el menú incluye a los tres perfiles y
  `perfilGuard` acepta varios perfiles. `npm run build` en verde (chunk `gestion`).
- **Paso 4 de Gestión hecho (verificación):** 14 pruebas unitarias + 6 de integración
  en verde; `dotnet build` 0 errores; smoke SQL real de `USP_CREA_CUENTA`,
  `USP_REGISTRA_TELEFONO`, `USP_REGISTRA_GESTION`, `USP_REGISTRA_PROMESA` y las 6
  consultas, dentro de `BEGIN TRAN`/`ROLLBACK` (5 conteos en 0 al final);
  `99_verificar.sql` muestra 586 empleados, 7 tipos de gestión y 0 datos operativos.
- **Paso 5: inventario real del `.exe` y menús 4+7 (2026-11-25).** El usuario corrigió
  que el `.exe` de Gestión tiene mucho más que `/asesor`: el `MenuStrip` de
  `FRM_GESTION_CARTERA.cs` define **Gestión (4 submenús)** y **Herramientas (7 submenús)**.
  Inventario entregado:
  - **Gestión (4):** `Nueva Gestion.` → `/asesor` (pantalla completa ya migrada);
    `Bloquear` → `/gestion/bloquear`; `Cancelar` → `/gestion/cancelar`;
    `Agendar Llamada.` → `/gestion/agendar-llamada`.
  - **Herramientas (7):** `Buscar.` → `/herramientas/buscar`; `Notas` →
    `/herramientas/notas`; `Bloc de Notas` → `/herramientas/bloc-notas`;
    `Calculadora` → `/herramientas/calculadora`; `Actualiza Información` →
    `/herramientas/actualiza-informacion`; `Expedientes` → `/herramientas/expedientes`;
    `Softphone` → `/herramientas/softphone`.
  - Implementación inicial: `CatalogoMenu` con campo `Grupo`; `OpcionMenu.grupo` en el
    front; encabezados de grupo en `shell.html`/`shell.css`. **Corrección 2026-11-25:**
    `OpcionMenuDto` no incluía `Grupo`, así que el frontend nunca recibía los encabezados;
    se agregó el campo y se mapeó `o.Grupo` en `ServicioSesion.ObtenerSesion`.
  - Además hay 12 pestañas dentro de `FRM_GESTION_CARTERA` (Cartera personalizada,
    Archivo Muerto, Demográficos/Email, Datos adicionales, Negociaciones, Promesas,
    Visitas, Gestiones, Subir Gestión, Adicionales cartera, Saldos, Cuestionario).
    Siguen siendo el siguiente inventario a migrar.
- **Paso 6: migración de muestra ejecutada (2026-11-25).** El linked server `BABEL189`
  quedó creado con `@provstr='Encrypt=no;TrustServerCertificate=true;'`, pero sus
  consultas devolvían 0 filas sin error; se descartó y se migró con conexión directa
  `SELECT` desde PowerShell, sin escribir jamás en `10.80.5.189`.
  Script: `database/BABEL_UNIFICADA/10_mig_operativo_muestra.ps1` (150 cuentas de
  `BANCO_AZTECA`, cartera 1, con sus entidades relacionadas). Resultado verificado:
  `ope.Cuenta` 150, `ope.Telefono` 383, `ope.Gestion` 278, `ope.Promesa` 39,
  `ope.Demografico` 8; 5 cargas `TERMINADA` en `mig.ControlCarga` (Ids 4-8);
  `ope.USP_CONSULTA_CUENTAS @IdCartera=1` devuelve las cuentas reales con cliente,
  saldo y empleado. El estado legacy `NEGE_ID_STATUS` se preserva dentro de
  `Comentario`; el tipo de gestión se fija en 1 hasta confirmar el catálogo con el área.
- **Paso 7: prueba manual pendiente del usuario.** Usuario `GESTOR` / `Babel2026!`,
  ruta `/asesor` y los 10 submenús. Tras la migración completa: F5, Ctrl+F5 y relogin.
  1. Entrar y confirmar “Cartera activa: BANCO_AZTECA”.
  2. Buscar una cuenta migrada por número, cliente o ID de control y abrirla.
  3. Agregar teléfono, guardar gestión y promesa reales.
  4. Probar Notas, Bloc de Notas, Calculadora, Actualiza Información, Expedientes,
     Softphone, Bloquear (receso), Agendar Llamada y Cancelar.
  5. Repetir con otra cuenta y, si quiere, usar “Cambia Cartera” (solo cambia la
     sesión; no escribe en BD).
- **Paso 8: 11 submenús funcionales (2026-11-25).** Se eliminó el componente informativo
  `LegacyModulo`: las 10 rutas `/gestion/*` y `/herramientas/*` usan ahora
  `features/herramienta/` con `data.modo`. Backend nuevo: `Herramientas.cs` (DTOs/contratos),
  `ServicioHerramientas` (cartera y empleado desde `IUsuarioActual`, nunca del cliente),
  `RepositorioHerramientas` (SPs `ope.USP_*`), `HerramientasController` (`api/herramientas`)
  y registros DI; `12_herramientas.sql` creó las tablas/SPs y ya está aplicado.
  `/asesor` lee `?id=` para abrir la cuenta seleccionada desde otras herramientas.
  Mapeo real verificado en los handlers de `FRM_GESTION_CARTERA.cs` y `MDL_CONSULTAS.cs`:
  - `Bloquear` controla recesos/break (`HIRE_RECESO`, `NEPG_RECESOS`), **no** bloqueo de cuenta.
  - `Calculadora` abre `FRM_NEGOCIACIONES`, no la calculadora de Windows.
  - `Agendar Llamada.` estaba inactivo en el legacy (sin handler, `Enabled=false`),
    pero se habilitó en el CRM porque el usuario pidió que todo funcione.
  - `Expedientes` muestra el consolidado migrado; no replica el acceso a PDFs por unidad
    de red legacy. `Softphone` registra la marcación en CRM; no implementa SIP real.
  - Se corrigió `CS1503` en `FinalizarRecesoAsync`: `byte` → `long` en interfaz y
    repositorio. `dotnet build` del Server: **0 errores**; `npm run build`: **0 errores**
    (`main-RPQY4SIC.js`).
- **Paso 9: migración operativa completa (2026-11-25, TERMINADA).** Script
  `11_mig_operativo_completo.ps1`, 13 carteras activas, lotes de 100000, staging en
  `mig.*`, control en `mig.ControlCarga`. El primer intento falló en cartera 3
  (`BAZ_MOVILIDAD`) por `Invalid column name 'NECU_GESTION_DESC'`: ese base tiene otro
  layout. El script ahora consulta `INFORMATION_SCHEMA.COLUMNS` en el remoto (solo
  `SELECT`) y usa `TRY_CONVERT` sobre columnas alternas para `Saldo`/`GestionDesc`, o
  `NULL` si no existen. Smoke de cartera 3 verificado: 54,747 cuentas y 16 cargas
  `TERMINADA` (13:45:52). Un segundo smoke con `$lote = 1000` murió por deadlock al
  insertar 4,906,000 teléfonos; se confirmó que no quedó proceso powershell activo y
  las cargas `INICIADA` se marcaron `CANCELADA`. Relanzamiento en background con log
  `%TEMP%\opencode\mig_completa_final.log`. **Segundo fallo (cartera 5 `MBA`):**
  `invalid column length from the bcp client for colid 3` porque
  `NECU_NOMBRE_CLIENTE` es `varchar(200)` en esa base y el staging tenía `varchar(60)`
  (`NECU_CUENTA` llega a `varchar(50)`). Inventario de longitudes máximas en las 13 bases
  (solo `SELECT`): se amplió `mig.StgCuenta.Numero` a 50 y `Cliente` a 200, y
  `ope.Demografico.Colonia`/`Delegacion`/`Estado` a 200. Carga huérfana marcada
  `CANCELADA` y relanzamiento con log `%TEMP%\opencode\mig_completa_final2.log`.
  **Resultado final (14:40:15, exit code 0, "Migración completa terminada"):**
  `ope.Cuenta` 435,760; `ope.Telefono` 904,915; `ope.Gestion` 237,605;
  `ope.Promesa` 20,881; `ope.Demografico` 318,365. Por cartera (cuentas): 1 `BANCO_AZTECA`
  67,802; 2 `BAZ_FRANQUICIA` 67,669; 3 `BAZ_MOVILIDAD` 54,747; 4 `NETMSYST_DEMO`
  6,808; 5 `MBA` 91,458; 6 `KUBO` 1,701; 7 `BAZ_EXEMPLEADOS` 2,669; 8 `TOTAL_PLAY`
  8,657; 9 `CONCREDITO` 6,808; 10 `SEARS` 66,933; 11 `SANBORNS` 0; 12
  `INBURSA_FIANZAS_TELCEL` 60,508; 13 `LSF_PRESTAMOS_PERSONALES` 0. Las carteras 11 y
  13 están vacías también en el legacy (`SELECT COUNT(*) FROM NECU_DATOSCUENTA` = 0 en
  ambas bases), no es pérdida ni dato inventado. `mig.ControlCarga`: **101 `TERMINADA`,
  0 `INICIADA`, 3 `CANCELADA`** de intentos anteriores. Siguiente paso: usuario hace
  F5 → Ctrl+F5 → relogin con `GESTOR` / `Babel2026!` y prueba `/asesor` + los 10
  submenús con datos migrados. Carga complementaria (`ope.MoraFuenteIngreso`,
  `ope.EvolucionCuenta`, notas/negociaciones) queda pendiente de aprobación visual.
  Se creó `database/BABEL_UNIFICADA/RECARGA/` con `README.md`, `00_BACKUP_LOCAL.sql`
  (backup local opcional), `01_TRUNCATE_OPERATIVO.sql` (TRUNCATE de `ope.*`, `mig.Stg*`
  y `mig.ControlCarga` deshabilitando/revalidando las 13 FKs con padre en `ope`),
  `02_RECARGA_COMPLETA.ps1` (todo en uno con log en `%TEMP%\opencode`) y
  `03_VERIFICAR_RECARGA.sql`. No se ejecutó: solo se validó sintaxis (`PARSEONLY` y
  parser de PowerShell). Advertencia documentada: no truncar `seg`, `rh`, `cart`,
  `cat`, `adm` ni `log` porque se perderían usuarios (incluido `GESTOR`, sin script
  automático de creación), empleados y carteras.
- **Verificación backend de Gestión (2026-11-25, sin escribir en BD):** la app ya
  estaba levantada (`localhost:5018` API, `localhost:51276` Angular). Login con
  `GESTOR` OK, menú 13 entradas (Inicio + Supervisión + 4 de Gestión + 7 de
  Herramientas). Cuenta de prueba real `IdCuenta=455198`
  (`1-1-7168-73347`, FRANCISCO JAVIER MENDEZ RUIZ): 4 teléfonos, 29 gestiones,
  7 promesas y 2 demográficos, todos leídos por la API. Agendas, notas y
  negociaciones devuelven 0 filas porque aún no se capturó nada en el CRM (no es
  error). Hay un receso `IdReceso=1` activo iniciado a las 15:38 por prueba del
  usuario. `/api/catalogos` devuelve 403 para `GESTOR` porque es política
  `Administrador`; no lo usan las pantallas de Gestión. **Pendiente:** que el
  usuario confirme visualmente pantalla por pantalla (F5 → Ctrl+F5 → relogin).
- **Verificación backend de Administración (2026-11-25, sin escribir en BD):**
  login `ADMIN` OK (`IdEmpleado=0`, perfil `Administrador`, cartera 1). Menú 17
  entradas: 4 de Gestión + 7 de Herramientas + 5 de Administración (Consulta de
  empleados, Alta de empleados, Asignar personal, Cambia cartera, Carga de
  asignaciones). GETs: `/api/catalogos` 200 (13 carteras), `/api/empleados` 200
  (586 activos; 232 en cartera 1), `/api/carteras` 200 (13),
  `/api/carteras/1/personal` 200 (586), `/api/carteras/operativo?idCartera=1` 200
  (0 filas), `/api/cargas/procesos` 200 (4 procesos), `/api/cargas?idCartera=1`
  200 (0 cargas). Las 5 rutas POST se probaron con JSON inválido: las 5 dieron
  400 de validación antes de ejecutar el servicio, así que están autorizadas y
  no se grabó nada (conteos intactos: 586 empleados, 586 asignaciones, 13
  carteras, 0 cargas, 2 usuarios). `GET /api/gestion/cuentas` con ADMIN también
  responde 200 porque la política `Gestion` incluye a `Administrador` (no es
  un error). **Limitación real pendiente:** `Carga de asignaciones` solo registra
  staging y responde "Carga recibida. Pendiente de validacion."; el procesamiento
  real sigue bloqueado por el SP cifrado `PROCESO_ASIGNACION` y el layout del
  Excel sin confirmar. **Pendiente:** confirmación visual de los 5 menús de
  Administración por parte del usuario.
- Sin commit. Rama `feat/unificador_babel`, cambios modified/untracked pendientes.

---

## 9. Referencias y rutas

### Repositorio

- `C:\Users\sbasilio\source\repos\Babel.Crm`
- Rama: `feat/unificador_babel`
- Scripts: `database/BABEL_UNIFICADA/`
- Backend: `UnoContact.Crm.Server`, `UnoContact.Crm.Application`,
  `UnoContact.Crm.Infrastructure`, `UnoContact.Crm.Domain`
- Frontend: `uno-contact-crm.client/`
- Pruebas: `tests/UnoContact.Crm.UnitTests`, `tests/UnoContact.Crm.IntegrationTests`

### Decompilados y análisis

- `C:\Users\sbasilio\Desktop\Trabajos\ingenieria inversa\APLICATIVOS\decompiled\ADMINISTRATIVO\HALCON_MILENARIO\`
  - `FRM_CONSULTAEMPLEADOS.cs`
  - `FRM_ALTAEMPLEADOS.cs`
  - `FRM_CONSULTA_BASE.cs` (Cambia Cartera)
  - `FRM_ASIGNARPERSONAL.cs`
  - `FRM_CARGAASIGNACIONES.cs`
- `...\decompiled\BABELGESTION\`
- `...\analysis\BABELGESTION.xml` — **contiene credenciales; no commitear.**

### Servidores

- **SQL local:** `localhost`, SQL Server 2025 Developer, Windows auth
  `UNOCONTACT\SBASILIO`, sysadmin, 668 GB libres.
- **SQL remoto:** `10.80.5.189,1433`, login `Netmesyst_Reportes`
  (credenciales en el XML de análisis; no repetirlas aquí), `db_owner`, sin sysadmin.
  Los SPs remotos están cifrados.

### Contratos legacy capturados

- `CONSULTA_NEEU_EMPLEADOS_MODULO` → 585 empleados; incluye contraseña en claro
  (no migrar).
- `CONSULTA_CABD_BASES_DATOS` → 28 bases; carteras 15–27.
- `CONSULTA_RECE_CLIENTE_EMPLEADO` → empleado 2 en base 15/BANCO_AZTECA/cartera 1.
- `INSERTA_NEEU_EMPLEADOS_MODULO`:
  `@ID_BASE, @ID_PUESTO, @ID_SEXO, @ID_TURNO, @NOMBRE, @PATERNO, @MATERNO, @EMPATAR`.
- `ACTUALIZA_AGENTE_BASE`:
  `@ID_AGENTE varchar(100), @ID_DEPARTAMENTO, @ID_BASE, @ID_CARTERA`.
- `INSERTA_TRAO_AGENTE_OPERATIVO`:
  `@ID_EMPLEADO, @ID_AGENTE, @ID_AREA_DEP, @ID_BASE, @ID_CARTERA,
   @ID_SEGMENTO, @ID_PRODUCTO, @ID_CAMPAÑA`.
- `RESTAURA_AGENTE_BASE`: `@ID_AGENTE, @ID_AREA_DEP, @ID_BASE`.
- `CONSULTA_NEEM_EMPLEADO_HALCON` columnas:
  `ID EMPLEADO, ID AREA DEPARTAMENTO, ID PUESTO, ID TURNO, ID HORARIO,
   NOMBRE, USUARIO, BLOQUEADO, ACTIVO, ID TIPO MARCACION, TIPO DE MARCACION,
   FOTO, BASE DE DATOS, ID BASE DE DATOS, CARTERA, ID CARTERA, SEGMENTO,
   ID SEGMENTO, PRODUCTO, ID PRODUCTO, CAMPAÑA, ID CAMPAÑA, AREA, DEPARTAMENTO`.
- `TRAO_AGENTE_OPERATIVO`:
  `TRAO_ID_REGISTRO, TRAO_ID_EMPLEADO, TRAO_ID_AGENTE, TRAO_ID_AREA_DEP,
   TRAO_ID_BASE, TRAO_ID_CARTERA, TRAO_ID_SEGMENTO, TRAO_ID_PRODUCTO,
   TRAO_ID_CAMPANA`.
- `REUM_USUARIO_MULTI_CARTERA`:
  `REUM_ID_REGISTRO, REUM_ID_EMPLEADO_CARGA, REUM_ID_BASE, REUM_ID_EMPLEADO,
   REUM_FECHA_REGISTRO`.
- `RECE_CLIENTE_EMPLEADO`:
  `RECE_ID_GCL_EMPL, RECE_ID_EMPL_ALTA, RECE_ID_EMPLEADO, RECE_ID_BASE,
   RECE_ID_CARTERA, RECE_ID_SEGMENTO, RECE_ID_PRODUCTO, RECE_ID_CAMPAÑA,
   RECE_FECHA_REGISTRO, RECE_FECHA_BAJA, RECE_ACTIVO`.
- `RHBABEL.NEEM_EMPLEADO` tiene 42 columnas; `NEEM_ID_EMPLEADO` es IDENTITY.
  Campos sensibles (`NEEM_CALLE_AVENIDA`, `NEEM_NUM_INT/EXT`, `NEEM_COLONIA`,
  `NEEM_SUELDO`, `NEEM_TEL_CASA/CEL/RECADOS`) son `varbinary`.

---

## 10. Seguridad y reglas

- **No migrar contraseñas legacy.** El login del CRM es propio (PBKDF2).
- **No commitear** `analysis/BABELGESTION.xml` ni archivos con credenciales.
- No usar datos de producción en pruebas; la base local debe quedar limpia.
- Los SPs remotos están cifrados; no intentar descifrarlos sin autorización.
- La cookie de sesión es `__Host-UnoContactCrm`, `Secure`, `HttpOnly`, `SameSite=Strict`;
  por eso el API debe probarse por HTTPS.
- Todo POST/PUT/DELETE a `/api` requiere el encabezado `X-UnoContact-Crm`.
- Antes de un commit: compilar, correr pruebas y probar el flujo manual.

---

## 11. Comandos rápidos

```powershell
# Estado del repo
cd C:\Users\sbasilio\source\repos\Babel.Crm
git status --short
git branch --show-current

# Base
sqlcmd -S localhost -E -C -d BABEL_UNIFICADA -Q "SELECT COUNT(*) FROM rh.Empleado;"

# Limpieza real aplicada tras la prueba del usuario (2026-11-25)
# Empleado karla perez perez (Id 2), carga 1 (DETALLE_CARTERA_V2.xlsx) y auditorías 5-7.
sqlcmd -S localhost -E -C -d BABEL_UNIFICADA -Q "SET QUOTED_IDENTIFIER ON; BEGIN TRAN; DELETE FROM log.Auditoria WHERE IdAuditoria IN (5,6,7); DELETE FROM adm.CargaAsignacionDetalle WHERE IdCarga = 1; DELETE FROM adm.CargaAsignacion WHERE IdCarga = 1; DELETE FROM ope.AgenteOperativo WHERE IdEmpleado = 2; DELETE FROM rh.EmpleadoCarteraAcceso WHERE IdEmpleado = 2; DELETE FROM rh.EmpleadoCartera WHERE IdEmpleado = 2; DELETE FROM rh.Empleado WHERE IdEmpleado = 2; COMMIT;"

# Verificar que quedó limpia (todo debe dar 0)
sqlcmd -S localhost -E -C -d BABEL_UNIFICADA -Q "SET NOCOUNT ON; SELECT (SELECT COUNT(*) FROM rh.Empleado) AS Empleados, (SELECT COUNT(*) FROM rh.EmpleadoCartera) AS Asignaciones, (SELECT COUNT(*) FROM ope.AgenteOperativo) AS Operativo, (SELECT COUNT(*) FROM adm.CargaAsignacion) AS Cargas, (SELECT COUNT(*) FROM log.Auditoria) AS Auditoria;"

# Ejecutar la migración de personal (re-ejecutable; solo lee bases locales)
sqlcmd -S localhost -E -C -b -d BABEL_UNIFICADA -f 65001 -i "database\BABEL_UNIFICADA\08_mig_personal.sql"

# Verificar la migración: 586 / 586 / 43 y 3 cargas TERMINADA
sqlcmd -S localhost -E -C -d BABEL_UNIFICADA -Q "SET NOCOUNT ON; SELECT (SELECT COUNT(*) FROM rh.Empleado) AS Empleados, (SELECT COUNT(*) FROM rh.EmpleadoCartera WHERE Activo=1) AS CarterasActivas, (SELECT COUNT(*) FROM rh.EmpleadoCarteraAcceso) AS Accesos; SELECT IdCarga, Entidad, FilasLeidas, FilasInsertadas, Estatus FROM mig.ControlCarga ORDER BY IdCarga;"

# Login directo al SP (ADMIN y GESTOR, ambos con Babel2026!)
sqlcmd -S localhost -E -C -d BABEL_UNIFICADA -Q "EXEC seg.USP_CONSULTA_USUARIO @Usuario='ADMIN'; EXEC seg.USP_CONSULTA_USUARIO @Usuario='GESTOR';"

# Verificar Gestión: 586 empleados, 7 tipos, 0 cuentas/teléfonos/gestiones/promesas
sqlcmd -S localhost -E -C -b -d BABEL_UNIFICADA -f 65001 -i "database\BABEL_UNIFICADA\99_verificar.sql"

# Aplicar el script de Herramientas (si no está aplicado)
sqlcmd -S localhost -E -C -b -d BABEL_UNIFICADA -i "database\BABEL_UNIFICADA\12_herramientas.sql"

# Migración operativa completa de las 13 carteras (SOLO SELECT en 10.80.5.189)
powershell -NoProfile -ExecutionPolicy Bypass -File "database\BABEL_UNIFICADA\11_mig_operativo_completo.ps1" 2>&1 |
  Tee-Object -FilePath "$env:TEMP\opencode\mig_completa_final.log"

# Conteos finales por cartera y estado de las cargas
sqlcmd -S localhost -E -C -d BABEL_UNIFICADA -Q "SET NOCOUNT ON; SELECT c.IdCartera, c.Nombre, COUNT(cu.IdCuenta) AS Cuentas FROM cart.Cartera c LEFT JOIN ope.Cuenta cu ON cu.IdCartera=c.IdCartera AND cu.IdControlLegacy>0 GROUP BY c.IdCartera,c.Nombre ORDER BY c.IdCartera; SELECT Estatus, COUNT(*) AS Cargas FROM mig.ControlCarga WHERE NombreCarga='OPERATIVO_COMPLETO_13_CARTERAS' GROUP BY Estatus;" -W

# Compilar y probar
dotnet build UnoContact.Crm.slnx --nologo -v minimal
dotnet test UnoContact.Crm.slnx --nologo -v minimal
cd uno-contact-crm.client; npm run build; cd ..

# API
$env:ASPNETCORE_ENVIRONMENT="Development"
dotnet run --project UnoContact.Crm.Server --no-build --no-launch-profile --urls "https://localhost:7263;http://localhost:5018"
```

---

## 12. Nota para quien retome

Si algo no coincide con este documento, **primero revisa el working tree y la base**:
puede haber cambios posteriores sin commit. No borres archivos que no entiendas;
varios son decompilados o respaldos del legacy. Si necesitas reiniciar la base,
vuelve a ejecutar los scripts en orden (son idempotentes en su mayoría) y verifica
con `99_verificar.sql`.
