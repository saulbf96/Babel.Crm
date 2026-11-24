using Babel.Crm.Application.Abstracciones;
using Babel.Crm.Application.Acceso;
using Babel.Crm.Application.Rh;
using Babel.Crm.Infrastructure.Identidad;
using Babel.Crm.Infrastructure.Rh;
using Babel.Crm.Infrastructure.Seguridad;
using Babel.Crm.Infrastructure.Persistencia;
using Babel.Crm.Infrastructure.Procedimientos;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Babel.Crm.Infrastructure;

public static class DependencyInjection
{
    public const string NombreCadenaConexion = "Babel";

    /// <summary>Registra base de datos, procedimientos almacenados y acceso con usuarios de BABEL.</summary>
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuracion)
    {
        services.Configure<OpcionesSeguridad>(configuracion.GetSection(OpcionesSeguridad.Seccion));
        services.Configure<OpcionesBaseDatos>(configuracion.GetSection(OpcionesBaseDatos.Seccion));
        services.Configure<MapeoPerfiles>(configuracion.GetSection(MapeoPerfiles.Seccion));

        // La cadena de conexión NO va en appsettings: user-secrets en desarrollo y
        // variables de entorno del servidor en IIS.
        services.AddDbContext<BabelDbContext>(opciones =>
        {
            var cadena = configuracion.GetConnectionString(NombreCadenaConexion);
            if (string.IsNullOrWhiteSpace(cadena))
            {
                throw new InvalidOperationException(
                    $"Falta la cadena de conexión '{NombreCadenaConexion}'. Configúrala con user-secrets (ver README).");
            }

            opciones.UseSqlServer(cadena);
        });

        services.AddMemoryCache();
        services.AddHttpContextAccessor();
        services.AddScoped<IUsuarioActual, UsuarioActualCookie>();
        services.AddScoped<IEjecutorProcedimientos, EjecutorProcedimientosSql>();
        // Login propio del CRM (BABEL_CRM.seg) con contraseñas PBKDF2.
        // El login viejo de BABEL (RepositorioUsuariosBabel) quedó fuera: sus SP están cifrados.
        services.AddSingleton<IHashContrasenas, HashContrasenasPbkdf2>();
        services.AddScoped<IRepositorioUsuarios, RepositorioUsuariosCrm>();
        services.AddScoped<IRepositorioEmpleados, RepositorioEmpleadosBabel>();
        services.AddSingleton<IControlIntentos, ControlIntentosMemoria>();

        return services;
    }
}
