using System.Security.Claims;
using UnoContact.Crm.Application.Acceso;
using UnoContact.Crm.Infrastructure.Identidad;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace UnoContact.Crm.Server.Controllers;

public sealed record IniciarSesionRequest(string Usuario, string Contrasena);

public sealed record IniciarSesionResponse(bool DebeCambiarContrasena);

/// <summary>Inicio y cierre de sesión con usuario y contraseña de BABEL (reemplaza FRM_ACCESO).</summary>
[ApiController]
[Route("api/acceso")]
public sealed class AccesoController(IServicioAcceso servicio, ILogger<AccesoController> bitacora) : ControllerBase
{
    public const string PoliticaLimiteAcceso = "acceso";

    [HttpPost("iniciar")]
    [AllowAnonymous]
    [EnableRateLimiting(PoliticaLimiteAcceso)]
    public async Task<IActionResult> Iniciar(IniciarSesionRequest request, CancellationToken cancelacion)
    {
        var ip = HttpContext.Connection.RemoteIpAddress?.ToString() ?? string.Empty;
        var resultado = await servicio.IniciarSesionAsync(
            new SolicitudAcceso(request.Usuario, request.Contrasena, ip, "CRM-WEB"),
            cancelacion);

        if (!resultado.Exitoso || resultado.Usuario is not { } usuario)
        {
            // Nunca se registra la contraseña.
            bitacora.LogWarning("Acceso rechazado para {Usuario} desde {Ip}", request.Usuario?.Trim().ToUpperInvariant(), ip);
            return Problem(statusCode: StatusCodes.Status401Unauthorized, title: resultado.Mensaje);
        }

        var claims = new List<Claim>
        {
            new(ClaimTypes.Name, usuario.Usuario),
            new(ClaimsBabel.IdEmpleado, usuario.IdEmpleado.ToString()),
            new(ClaimsBabel.IdPuesto, usuario.IdPuesto.ToString()),
            new(ClaimsBabel.IdArea, usuario.IdArea.ToString()),
            new(ClaimsBabel.IdBaseDatos, usuario.IdBaseDatos.ToString()),
        };
        claims.AddRange(resultado.Perfiles!.Select(p => new Claim(ClaimsBabel.Perfil, p.ToString())));

        var identidad = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);
        await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, new ClaimsPrincipal(identidad));

        bitacora.LogInformation("Acceso correcto de {Usuario} (empleado {IdEmpleado}) desde {Ip}", usuario.Usuario, usuario.IdEmpleado, ip);
        return Ok(new IniciarSesionResponse(resultado.DebeCambiarContrasena));
    }

    [HttpPost("cerrar")]
    public async Task<IActionResult> Cerrar()
    {
        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        return NoContent();
    }
}
