# BABEL CRM

CRM web que reemplaza a los aplicativos de escritorio **BABEL GESTION** (asesor) y **BABEL ADMINISTRATIVO** (back office).
Trabaja sobre las mismas bases de SQL Server y sus procedimientos almacenados, para convivir con el escritorio durante la migración.

## Tecnología

| Parte | Tecnología |
|---|---|
| Backend | ASP.NET Core Web API, .NET 10 (C#) |
| Frontend | Angular 22 + Angular Material |
| Datos | SQL Server, EF Core 10 y procedimientos almacenados |
| Servidor | IIS |

## Estructura

```
Babel.Crm.slnx
├─ Babel.Crm.Domain          Entidades y reglas puras (perfiles, puestos)
├─ Babel.Crm.Application     Casos de uso e interfaces (acceso, sesión, menú)
├─ Babel.Crm.Infrastructure  EF Core, ejecución de procedimientos, usuarios de BABEL
├─ Babel.Crm.Server          Web API (controladores, seguridad, bitácora)
├─ babel.crm.client          Angular 22 + Material
└─ tests
   ├─ Babel.Crm.UnitTests
   └─ Babel.Crm.IntegrationTests
```

Dependencias: `Server → Application + Infrastructure`, `Infrastructure → Application`, `Application → Domain`.

## Inicio de sesión

Igual que BABEL: **usuario y contraseña de BABEL**, validados con `CONFIGURACION_APP.DBO.CONSULTA_NEEM_EMPLEADO`.

- Al tercer intento fallido se bloquea al usuario (`LOGSSISTEMA.DBO.INSERTA_HIBP_LOG_BLOQUEOS_PERSONAL`).
- El perfil (Asesor, Supervisor, Administrador) sale del **puesto** del empleado: `Seguridad:PuestosPorPerfil` en `appsettings.json` (tabla por confirmar con usuarios).
- La sesión es una cookie `HttpOnly`, `Secure`, `SameSite=Strict` que vence tras 30 minutos sin actividad.
- Diferencias con el escritorio: no existe acceso "fuera de línea", la contraseña nunca se escribe en bitácora y los usuarios inactivos no entran.

## Configuración local (secretos)

Los secretos **no van en el código ni en `appsettings.json`**. En Visual Studio: clic derecho en `Babel.Crm.Server` → **Administrar secretos de usuario** y captura:

```json
{
  "ConnectionStrings": {
    "Babel": "Server=localhost;Database=CONFIGURACION_APP;Integrated Security=true;TrustServerCertificate=true"
  },
  "Seguridad": {
    "LlaveBabel": "<la pide el líder técnico; nunca se sube al repositorio>"
  }
}
```

Usa siempre una base **local o de pruebas**, nunca la de producción.

## Ejecutar

1. Abre `Babel.Crm.slnx` en Visual Studio.
2. Proyecto de inicio: `Babel.Crm.Server` (perfil `https`).
3. **F5**. Arranca la API y Angular; el navegador abre la pantalla de acceso.

Se abre **solo Chrome**: el navegador lo abre el proyecto de Angular (`babel.crm.client/.vscode/launch.json`, perfil "localhost (Chrome)"); la API no abre navegador (`launchBrowser: false`).

URLs de desarrollo: Angular `https://localhost:51276`, API `https://localhost:7263`, salud `https://localhost:7263/api/salud`.

## Pruebas

```powershell
dotnet test                      # .NET (unitarias e integración)
cd babel.crm.client; npx ng test --watch=false   # Angular (Vitest)
```

## Publicar en IIS

1. Clic derecho en `Babel.Crm.Server` → **Publicar** → Carpeta. Angular se compila y queda dentro del sitio.
2. En el servidor: Hosting Bundle de .NET 10, sitio con HTTPS y grupo de aplicaciones "Sin código administrado".
3. Secretos del servidor como variables de entorno del grupo de aplicaciones: `ConnectionStrings__Babel` y `Seguridad__LlaveBabel`.

## Reglas del repositorio

- Ramas: `feature/*` → `Preprod` → `master`.
- El código descompilado de BABEL **no** se sube aquí.
- Nunca se suben secretos ni datos reales de clientes o empleados.
