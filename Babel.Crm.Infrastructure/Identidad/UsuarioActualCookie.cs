using System.Security.Claims;
using Babel.Crm.Application.Abstracciones;
using Babel.Crm.Domain.Seguridad;
using Microsoft.AspNetCore.Http;

namespace Babel.Crm.Infrastructure.Identidad;

/// <summary>Nombres de los datos (claims) que se guardan en la cookie de sesión.</summary>
public static class ClaimsBabel
{
    public const string IdEmpleado = "babel:id_empleado";
    public const string IdPuesto = "babel:id_puesto";
    public const string IdArea = "babel:id_area";
    public const string IdBaseDatos = "babel:id_base_datos";
    public const string Perfil = ClaimTypes.Role;
}

/// <summary>Usuario actual leído de la cookie de sesión del CRM.</summary>
public sealed class UsuarioActualCookie(IHttpContextAccessor accesoHttp) : IUsuarioActual
{
    private ClaimsPrincipal? Principal => accesoHttp.HttpContext?.User;

    public bool EstaAutenticado => Principal?.Identity?.IsAuthenticated == true;

    public int IdEmpleado =>
        int.TryParse(Principal?.FindFirstValue(ClaimsBabel.IdEmpleado), out var id) ? id : 0;

    public string Usuario => EstaAutenticado ? Principal!.Identity!.Name ?? string.Empty : string.Empty;

    public IReadOnlyCollection<Perfil> Perfiles =>
        EstaAutenticado
            ? Principal!.FindAll(ClaimsBabel.Perfil)
                .Select(c => Enum.TryParse<Perfil>(c.Value, out var p) ? p : (Perfil?)null)
                .OfType<Perfil>()
                .Distinct()
                .ToList()
            : [];
}
