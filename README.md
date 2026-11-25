# UNO Contact CRM

CRM web que reemplaza a los aplicativos de escritorio **BABEL GESTION** (asesor) y **BABEL ADMINISTRATIVO** (back office).
Trabaja sobre una **base local unificada** (`BABEL_UNIFICADA`) con `IdCartera` en las tablas de negocio, sin una base por cartera.

## Tecnología

| Parte | Tecnología |
|---|---|
| Backend | ASP.NET Core Web API, .NET 10 (C#) |
| Frontend | Angular 22 + Angular Material |
| Datos | SQL Server, EF Core 10 y procedimientos almacenados |
| Servidor | IIS |

## Estructura

```
UnoContact.Crm.slnx
├─ UnoContact.Crm.Domain          Entidades y reglas puras (perfiles, puestos)
├─ UnoContact.Crm.Application     Casos de uso e interfaces (acceso, sesión, menú)
├─ UnoContact.Crm.Infrastructure  EF Core, ejecución de procedimientos, usuarios del CRM
├─ UnoContact.Crm.Server          Web API (controladores, seguridad, bitácora)
├─ uno-contact-crm.client          Angular 22 + Material
└─ tests
   ├─ UnoContact.Crm.UnitTests
   └─ UnoContact.Crm.IntegrationTests
```

Dependencias: `Server → Application + Infrastructure`, `Infrastructure → Application`, `Application → Domain`.

## Inicio de sesión

Login **propio del CRM**: usuarios en la base `BABEL_UNIFICADA` (esquema `seg`) con contraseñas **PBKDF2** (nunca en claro). El login del escritorio no se reutiliza porque sus procedimientos están cifrados y la llave ya no se tiene.

- Al tercer intento fallido se bloquea al usuario y se registra en `BABEL_UNIFICADA.log.AccesoBloqueo`.
- El perfil (Asesor, Supervisor, Administrador) sale del **puesto** del usuario: `Seguridad:PuestosPorPerfil` en `appsettings.json` (tabla por confirmar con usuarios).
- La sesión es una cookie `HttpOnly`, `Secure`, `SameSite=Strict` que vence tras 30 minutos sin actividad.
- La contraseña nunca se escribe en bitácora y los usuarios inactivos o bloqueados no entran.

Usuario de prueba (solo local): **ADMIN** / **Babel2026!** (créalo con `database/BABEL_UNIFICADA/04_seg_usuarios.sql`).

## Módulos de Administración

| Pantalla | Estado |
|---|---|
| Consulta de empleados | Funcional |
| Alta de empleados | Funcional |
| Cambia cartera | Funcional (cambio de sesión) |
| Asignar personal a cartera | Funcional (asignar, operativo y restaurar) |
| Carga de asignaciones | Staging: registra archivo e historial; el proceso real está pendiente |

## Configuración local (secretos)

Los secretos **no van en el código ni en `appsettings.json`**. En Visual Studio: clic derecho en `UnoContact.Crm.Server` → **Administrar secretos de usuario** y captura:

```json
{
  "ConnectionStrings": {
    "UnoContact": "Server=localhost;Database=BABEL_UNIFICADA;Integrated Security=true;TrustServerCertificate=true"
  }
}
```

Usa siempre una base **local o de pruebas**, nunca la de producción. La base `BABEL_UNIFICADA` se crea con los scripts de `database/BABEL_UNIFICADA/` (01 a 06, en ese orden).

## Ejecutar

1. Abre `UnoContact.Crm.slnx` en Visual Studio.
2. Proyecto de inicio: `UnoContact.Crm.Server` (perfil `https`).
3. **F5**. Arranca la API y Angular; el navegador abre la pantalla de acceso.

En desarrollo, la raíz del API redirige a Angular (`SpaProxy:Url` en
`appsettings.Development.json`). Si el navegador no abre, revisa que el perfil sea
`https` y que `launchBrowser` esté en `true` en `launchSettings.json`.

Se abre **solo Chrome**: el navegador lo abre el proyecto de Angular (`uno-contact-crm.client/.vscode/launch.json`, perfil "localhost (Chrome)"); la API no abre navegador (`launchBrowser: false`).

URLs de desarrollo: Angular `https://localhost:51276`, API `https://localhost:7263`, salud `https://localhost:7263/api/salud`.

## Pruebas

```powershell
dotnet test                      # .NET (unitarias e integración)
cd uno-contact-crm.client; npx ng test --watch=false   # Angular (Vitest)
```

## Publicar en IIS

1. Clic derecho en `UnoContact.Crm.Server` → **Publicar** → Carpeta. Angular se compila y queda dentro del sitio.
2. En el servidor: Hosting Bundle de .NET 10, sitio con HTTPS y grupo de aplicaciones "Sin código administrado".
3. Secretos del servidor como variable de entorno del grupo de aplicaciones: `ConnectionStrings__UnoContact`.

## Reglas del repositorio

- Ramas: `feature/*` → `Preprod` → `master`.
- El código descompilado de BABEL **no** se sube aquí.
- Nunca se suben secretos ni datos reales de clientes o empleados.
