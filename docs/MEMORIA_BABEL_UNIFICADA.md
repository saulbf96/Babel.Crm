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
> **Paso actual (2026-11-25):** **Administración terminada, compilada y probada por el
> usuario** (`ADMIN` / `Babel2026!`). El Alta se ajustó a paridad con el `.exe`: usa la
> cartera activa de la sesión y exige apellido materno. Sigue la **migración de datos
> legacy** (solo lo que confirme el personal) y luego **Gestión**.

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
- Se creó y ejecutó `BABEL_UNIFICADA` con sus 7 scripts (ver sección 3).
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
- Compilación y pruebas: `dotnet build` OK, 8 unitarias + 6 integración en verde,
  `npm run build` OK. La prueba de integración nueva valida que el alta sin materno da 400.

### En curso / pendiente inmediato

- **Limpieza:** borrar los datos de prueba que dejó el usuario (1 empleado, 2 asignaciones,
  1 carga) antes de migrar; ver SQL de limpieza en la sección 11.
- **Migración legacy:** definir con el personal qué datos se migran y ejecutarla.
- **Gestión:** iniciar el análisis de `decompiled/BABELGESTION/` y sus pantallas.
- Agregar una tabla de control de migración (`mig.*`) antes de copiar datos legacy,
  para registrar origen, filas y fecha de cada carga.

### Bloqueado

- `Carga de asignaciones` real depende del SP cifrado
  `PROCESOS_CLIENTES.DBO.PROCESO_ASIGNACION_<base>` y de conocer el layout exacto del
  Excel. El `.exe` copiaba el archivo a `\\10.80.5.189\BANCO AZTECA\ASIGNACIONES\` y
  llamaba ese SP; por ahora solo existen tablas y SPs de staging.
- Faltan por respaldar/restaurar localmente 12 bases de cartera (solo está
  `NETMSYST_DEMO`); se necesitan para la migración completa de datos.
- El T-SQL de los SPs legacy sigue cifrado; solo se conocen firmas/columnas.

---

## 3. Base de datos `BABEL_UNIFICADA`

### Scripts (ejecutar en este orden)

Carpeta: `database/BABEL_UNIFICADA/`

| Script | Contenido |
|---|---|
| `01_crear_base.sql` | Crea la base, esquemas `seg/rh/cart/ope/adm/cat/log` y bitácora. |
| `02_catalogos.sql` | Puestos (29), departamentos (25), sexos (3), turnos (6), clientes (13), carteras (13). |
| `03_rh_empleados.sql` | `rh.Empleado`, `rh.EmpleadoCartera`, `rh.EmpleadoCarteraAcceso`, consulta/alta y catálogos. |
| `04_seg_usuarios.sql` | `seg.Usuario`, login, bloqueo, usuario ADMIN. |
| `05_cart_asignaciones.sql` | Carteras, validación, personal, asignar/restaurar y operativo. |
| `06_adm_carga_asignaciones.sql` | Staging de carga de asignaciones. |
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

### Usuario de prueba

- **Usuario:** `ADMIN`
- **Contraseña:** `Babel2026!`
- `IdPuesto = 1` (Administrador), `IdDepartamento = 12`, `DebeCambiarContrasena = 0`.
- Hash PBKDF2-SHA256 en `seg.Usuario`; nunca se guarda en claro.

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
- `ope.AgenteOperativo`
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

- **Sexo:** el catálogo legacy solo etiqueta 1=Masculino y 2=Femenino; 3/4 salen en
  blanco. Catálogo nuevo: 1=Masculino, 2=Femenino, 3=Otro. Al migrar: 3→2 y 4→3.
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
   - Reiniciar la app para cargar el cambio.
   - Confirmar que no hay selector de cartera, se muestra la cartera activa y el
     materno es obligatorio.

3. **Limpieza de datos de prueba**
   - Borrar 1 empleado, 2 asignaciones y 1 carga (SQL en la sección 11).

4. **Migración legacy (solo lo que confirme el personal)**
   - Definir con el personal qué empleados/asignaciones se migran.
   - Agregar `mig.ControlCarga` con origen, fecha, filas y usuario.
   - Respaldar/restaurar las 12 bases de cartera que faltan (hoy solo `NETMSYST_DEMO`).
   - Migrar empleados y su cartera activa usando `IdEmpleadoLegacy`/`IdRegistroLegacy`.
   - Migrar también segmento/producto/campaña del empleado para el operativo
     (pendiente 4: Babel los hereda del registro, no los captura en pantalla).
   - **No migrar contraseñas**; el CRM usa PBKDF2.
   - Validar conteos contra `CONSULTA_NEEU_EMPLEADOS_MODULO` (585 empleados remotos).

5. **Gestión**
   - Revisar `decompiled/BABELGESTION/` y `analysis/BABELGESTION.xml`.
   - Mapear pantallas a `ope.*` y `cart.*`; empezar por la gestión de cartera del asesor.

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
- Antes de migrar: respaldar/restaurar las 12 bases de cartera que faltan
  (hoy solo está `NETMSYST_DEMO`).

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

# Limpiar un empleado de prueba (ajusta nombre/apellido)
sqlcmd -S localhost -E -C -d BABEL_UNIFICADA -Q "SET QUOTED_IDENTIFIER ON; DECLARE @id int = (SELECT IdEmpleado FROM rh.Empleado WHERE Nombre='PRUEBA' AND Paterno='FLUJO'); DELETE FROM ope.AgenteOperativo WHERE IdEmpleado=@id; DELETE FROM rh.EmpleadoCarteraAcceso WHERE IdEmpleado=@id; DELETE FROM rh.EmpleadoCartera WHERE IdEmpleado=@id; DELETE FROM rh.Empleado WHERE IdEmpleado=@id;"

# Login directo al SP
sqlcmd -S localhost -E -C -d BABEL_UNIFICADA -Q "EXEC seg.USP_CONSULTA_USUARIO @Usuario='ADMIN';"

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
