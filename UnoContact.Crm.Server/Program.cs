using System.Threading.RateLimiting;
using UnoContact.Crm.Application;
using UnoContact.Crm.Domain.Seguridad;
using UnoContact.Crm.Infrastructure;
using UnoContact.Crm.Server.Controllers;
using UnoContact.Crm.Server.Infraestructura;
using Microsoft.AspNetCore.Authentication.Cookies;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

// Bitácora (sección "Serilog" de appsettings).
builder.Host.UseSerilog((contexto, configuracion) => configuracion.ReadFrom.Configuration(contexto.Configuration));

builder.Services.AddApplication();
builder.Services.AddInfrastructure(builder.Configuration);

// Sesión con cookie segura después de validar usuario y contraseña de BABEL.
builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(opciones =>
    {
        opciones.Cookie.Name = "__Host-UnoContactCrm";
        opciones.Cookie.HttpOnly = true;
        opciones.Cookie.SecurePolicy = CookieSecurePolicy.Always;
        opciones.Cookie.SameSite = SameSiteMode.Strict;
        opciones.ExpireTimeSpan = TimeSpan.FromMinutes(30); // cierre por inactividad
        opciones.SlidingExpiration = true;
        // Es una API: responde 401/403 en lugar de redirigir a una página de login.
        opciones.Events.OnRedirectToLogin = c => { c.Response.StatusCode = StatusCodes.Status401Unauthorized; return Task.CompletedTask; };
        opciones.Events.OnRedirectToAccessDenied = c => { c.Response.StatusCode = StatusCodes.Status403Forbidden; return Task.CompletedTask; };
    });

// Por defecto todo exige sesión; además hay una política por perfil: [Authorize(Policy = "Administrador")].
builder.Services.AddAuthorization(opciones =>
{
    opciones.FallbackPolicy = opciones.DefaultPolicy;
    foreach (var perfil in Enum.GetValues<Perfil>())
    {
        opciones.AddPolicy(perfil.ToString(), p => p.RequireRole(perfil.ToString()));
    }
});

// Máximo 10 intentos de inicio de sesión por minuto por IP.
builder.Services.AddRateLimiter(opciones =>
{
    opciones.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    opciones.AddPolicy(AccesoController.PoliticaLimiteAcceso, contexto =>
        RateLimitPartition.GetFixedWindowLimiter(
            contexto.Connection.RemoteIpAddress?.ToString() ?? "sin-ip",
            _ => new FixedWindowRateLimiterOptions { PermitLimit = 10, Window = TimeSpan.FromMinutes(1) }));
});

builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<ManejadorErrores>();
builder.Services.AddControllers();
builder.Services.AddOpenApi();
builder.Services.AddHealthChecks();

var app = builder.Build();

app.UseExceptionHandler();
if (!app.Environment.IsDevelopment())
{
    app.UseHsts();
}

// Encabezados de seguridad (OWASP / ASVS).
app.Use(async (contexto, siguiente) =>
{
    var h = contexto.Response.Headers;
    h.XContentTypeOptions = "nosniff";
    h.XFrameOptions = "DENY";
    h["Referrer-Policy"] = "no-referrer";
    h["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()";
    await siguiente();
});

// Protección CSRF: toda petición que modifica datos en /api debe traer el encabezado que agrega Angular.
// Junto con la cookie SameSite=Strict impide que otro sitio dispare acciones con la sesión del usuario.
app.Use(async (contexto, siguiente) =>
{
    var metodo = contexto.Request.Method;
    var modifica = !(HttpMethods.IsGet(metodo) || HttpMethods.IsHead(metodo) || HttpMethods.IsOptions(metodo));
    if (modifica && contexto.Request.Path.StartsWithSegments("/api")
        && !contexto.Request.Headers.ContainsKey("X-UnoContact-Crm"))
    {
        contexto.Response.StatusCode = StatusCodes.Status400BadRequest;
        return;
    }

    await siguiente();
});

app.UseSerilogRequestLogging();
app.UseDefaultFiles();
app.MapStaticAssets().AllowAnonymous();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi().AllowAnonymous();
}

app.UseHttpsRedirection();

// En desarrollo, Visual Studio abre la raíz del API; se redirige a Angular
// para que el navegador caiga directo en la pantalla de login del CRM.
if (app.Environment.IsDevelopment())
{
    var urlSpa = app.Configuration["SpaProxy:Url"] ?? "https://localhost:51276";
    app.Use(async (contexto, siguiente) =>
    {
        if (contexto.Request.Path == "/")
        {
            contexto.Response.Redirect(urlSpa);
            return;
        }

        await siguiente();
    });
}

app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

app.MapHealthChecks("/api/salud").AllowAnonymous();
app.MapControllers();
app.MapFallbackToFile("/index.html").AllowAnonymous();

app.Run();

public partial class Program;
