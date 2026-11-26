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

public sealed record IniciarSesionResponse(bool DebeCambiarContrasena, string? MotivoCambioContrasena);

public sealed record CambiarContrasenaRequest(string Nueva);

/// <summary>Inicio y cierre de sesión con usuario y contraseña de BABEL (reemplaza FRM_ACCESO).</summary>
[ApiController]
[Route("api/acceso")]
public sealed class AccesoController(
    IServicioAcceso servicio,
    IServicioCambioContrasena cambioContrasena,
    ILogger<AccesoController> bitacora) : ControllerBase
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
            new(ClaimsBabel.IdUsuario, usuario.IdUsuario.ToString()),
            new(ClaimsBabel.IdEmpleado, usuario.IdEmpleado.ToString()),
            new(ClaimsBabel.IdPuesto, usuario.IdPuesto.ToString()),
            new(ClaimsBabel.IdArea, usuario.IdArea.ToString()),
            new(ClaimsBabel.IdCartera, usuario.IdCartera.ToString()),
            new(ClaimsBabel.Cartera, usuario.Cartera),
            new(ClaimsBabel.DebeCambiarContrasena, resultado.DebeCambiarContrasena ? "1" : "0"),
            new(ClaimsBabel.MotivoCambioContrasena, resultado.MotivoCambio.ToString()),
        };
        claims.AddRange(resultado.Perfiles!.Select(p => new Claim(ClaimsBabel.Perfil, p.ToString())));
        claims.AddRange((resultado.Permisos ?? []).Select(p => new Claim(ClaimsBabel.Permiso, p)));
        claims.Add(new Claim(ClaimsBabel.Root, usuario.EsRoot ? "1" : "0"));

        var identidad = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);
        await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, new ClaimsPrincipal(identidad));

        bitacora.LogInformation("Acceso correcto de {Usuario} (empleado {IdEmpleado}) desde {Ip}", usuario.Usuario, usuario.IdEmpleado, ip);
        return Ok(new IniciarSesionResponse(
            resultado.DebeCambiarContrasena,
            resultado.DebeCambiarContrasena ? resultado.MotivoCambio.ToString() : null));
    }

    /// <summary>Cambio de contraseña del usuario autenticado (equivale a FRM_CAMBIOPASS).</summary>
    [HttpPost("cambiar-contrasena")]
    [Authorize]
    public async Task<IActionResult> CambiarContrasena(CambiarContrasenaRequest request, CancellationToken cancelacion)
    {
        var idUsuario = int.TryParse(User.FindFirstValue(ClaimsBabel.IdUsuario), out var id) ? id : 0;
        if (idUsuario == 0)
        {
            return Problem(statusCode: StatusCodes.Status401Unauthorized, title: "Sesión no válida.");
        }

        // Regla de composición + no repetir la actual ni las últimas N: SIEMPRE en el servidor.
        var error = await cambioContrasena.CambiarAsync(idUsuario, request.Nueva, cancelacion);
        if (error is not null)
        {
            return Problem(statusCode: StatusCodes.Status400BadRequest, title: error);
        }

        // Reemitir la cookie con la bandera en 0 para que la sesión ya no exija el cambio.
        var claims = User.Claims
            .Where(c => c.Type != ClaimsBabel.DebeCambiarContrasena && c.Type != ClaimsBabel.MotivoCambioContrasena)
            .Append(new Claim(ClaimsBabel.DebeCambiarContrasena, "0"))
            .ToList();
        var identidad = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);
        await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, new ClaimsPrincipal(identidad));

        bitacora.LogInformation("Contraseña cambiada por el usuario {Usuario}", User.Identity?.Name);
        return NoContent();
    }

    [HttpPost("cerrar")]
    public async Task<IActionResult> Cerrar()
    {
        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        return NoContent();
    }
}
