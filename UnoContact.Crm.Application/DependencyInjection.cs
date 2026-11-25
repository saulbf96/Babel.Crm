using UnoContact.Crm.Application.Acceso;
using UnoContact.Crm.Application.Rh;
using UnoContact.Crm.Application.Sesion;
using Microsoft.Extensions.DependencyInjection;

namespace UnoContact.Crm.Application;

public static class DependencyInjection
{
    /// <summary>Registra los casos de uso de la capa de aplicación.</summary>
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddScoped<IServicioSesion, ServicioSesion>();
        services.AddScoped<IServicioAcceso, ServicioAcceso>();
        services.AddScoped<IServicioEmpleados, ServicioEmpleados>();
        return services;
    }
}
