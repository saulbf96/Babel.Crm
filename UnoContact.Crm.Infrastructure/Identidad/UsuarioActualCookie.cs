using System.Security.Claims;
using UnoContact.Crm.Application.Abstracciones;
using UnoContact.Crm.Domain.Seguridad;
using Microsoft.AspNetCore.Http;

namespace UnoContact.Crm.Infrastructure.Identidad;

/// <summary>Nombres de los datos (claims) que se guardan en la cookie de sesión.</summary>
public static class ClaimsBabel
{
    public const string IdEmpleado = "babel:id_empleado";
    public const string IdUsuario = "babel:id_usuario";
    public const string IdPuesto = "babel:id_puesto";
    public const string IdArea = "babel:id_area";
    public const string IdCartera = "babel:id_cartera";
    public const string Cartera = "babel:cartera";
    public const string DebeCambiarContrasena = "babel:debe_cambiar";
    public const string MotivoCambioContrasena = "babel:motivo_cambio";
    public const string Perfil = ClaimTypes.Role;
}

/// <summary>Usuario actual leído de la cookie de sesión del CRM.</summary>
public sealed class UsuarioActualCookie(IHttpContextAccessor accesoHttp) : IUsuarioActual
{
    private ClaimsPrincipal? Principal => accesoHttp.HttpContext?.User;

    public bool EstaAutenticado => Principal?.Identity?.IsAuthenticated == true;

    public int IdEmpleado =>
        int.TryParse(Principal?.FindFirstValue(ClaimsBabel.IdEmpleado), out var id) ? id : 0;

    public int IdUsuario =>
        int.TryParse(Principal?.FindFirstValue(ClaimsBabel.IdUsuario), out var id) ? id : 0;

    public string Usuario => EstaAutenticado ? Principal!.Identity!.Name ?? string.Empty : string.Empty;

    public int IdCartera =>
        int.TryParse(Principal?.FindFirstValue(ClaimsBabel.IdCartera), out var id) ? id : 0;

    public string Cartera =>
        Principal?.FindFirstValue(ClaimsBabel.Cartera) ?? string.Empty;

    public bool DebeCambiarContrasena =>
        Principal?.FindFirstValue(ClaimsBabel.DebeCambiarContrasena) == "1";

    public string? MotivoCambioContrasena =>
        DebeCambiarContrasena ? Principal?.FindFirstValue(ClaimsBabel.MotivoCambioContrasena) : null;

    public IReadOnlyCollection<Perfil> Perfiles =>
        EstaAutenticado
            ? Principal!.FindAll(ClaimsBabel.Perfil)
                .Select(c => Enum.TryParse<Perfil>(c.Value, out var p) ? p : (Perfil?)null)
                .OfType<Perfil>()
                .Distinct()
                .ToList()
            : [];
}
