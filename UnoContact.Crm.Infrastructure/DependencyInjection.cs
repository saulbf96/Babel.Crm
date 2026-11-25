using UnoContact.Crm.Application.Abstracciones;
using UnoContact.Crm.Application.Acceso;
using UnoContact.Crm.Application.Adm;
using UnoContact.Crm.Application.Carteras;
using UnoContact.Crm.Application.Catalogos;
using UnoContact.Crm.Application.Gestion;
using UnoContact.Crm.Application.Rh;
using UnoContact.Crm.Infrastructure.Adm;
using UnoContact.Crm.Infrastructure.Carteras;
using UnoContact.Crm.Infrastructure.Catalogos;
using UnoContact.Crm.Infrastructure.Gestion;
using UnoContact.Crm.Infrastructure.Identidad;
using UnoContact.Crm.Infrastructure.Rh;
using UnoContact.Crm.Infrastructure.Seguridad;
using UnoContact.Crm.Infrastructure.Persistencia;
using UnoContact.Crm.Infrastructure.Procedimientos;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace UnoContact.Crm.Infrastructure;

public static class DependencyInjection
{
    public const string NombreCadenaConexion = "UnoContact";

    /// <summary>Registra base de datos, procedimientos almacenados y el acceso con usuarios del CRM.</summary>
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuracion)
    {
        services.Configure<OpcionesBaseDatos>(configuracion.GetSection(OpcionesBaseDatos.Seccion));
        services.Configure<MapeoPerfiles>(configuracion.GetSection(MapeoPerfiles.Seccion));

        // La cadena de conexión NO va en appsettings: user-secrets en desarrollo y
        // variables de entorno del servidor en IIS.
        services.AddDbContext<UnoContactDbContext>(opciones =>
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
        // Login propio del CRM (base BABEL_UNIFICADA, esquema seg) con contraseñas PBKDF2.
        // El login del aplicativo de escritorio quedó fuera: sus procedimientos están cifrados.
        services.AddSingleton<IHashContrasenas, HashContrasenasPbkdf2>();
        services.AddScoped<IRepositorioUsuarios, RepositorioUsuariosCrm>();
        services.AddScoped<IRepositorioEmpleados, RepositorioEmpleados>();
        services.AddScoped<IRepositorioCatalogos, RepositorioCatalogos>();
        services.AddScoped<IRepositorioCarteras, RepositorioCarteras>();
        services.AddScoped<IRepositorioCargas, RepositorioCargas>();
        services.AddScoped<IRepositorioGestion, RepositorioGestion>();
        services.AddScoped<IRepositorioHerramientas, RepositorioHerramientas>();
        services.AddSingleton<IControlIntentos, ControlIntentosMemoria>();

        return services;
    }
}
