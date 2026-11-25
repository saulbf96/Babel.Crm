using System.Security.Claims;
using UnoContact.Crm.Application.Carteras;
using UnoContact.Crm.Application.Sesion;
using UnoContact.Crm.Infrastructure.Identidad;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Mvc;

namespace UnoContact.Crm.Server.Controllers;

public sealed record CambiarCarteraRequest(byte IdCartera);

public sealed record CarteraSesionResponse(byte IdCartera, string Nombre);

/// <summary>
/// Sesión del usuario autenticado: perfiles, menú y cambio de cartera.
/// El .exe solo cambiaba MDL_INICIO.ID_BBDD; aquí se reemite la cookie con la nueva cartera.
/// </summary>
[ApiController]
[Route("api/sesion")]
public sealed class SesionController(
    IServicioSesion servicio,
    IServicioCarteras carteras) : ControllerBase
{
    [HttpGet]
    public ActionResult<SesionDto> Get() => servicio.ObtenerSesion();

    [HttpPost("cartera")]
    public async Task<ActionResult<CarteraSesionResponse>> CambiarCartera(
        CambiarCarteraRequest solicitud,
        CancellationToken cancelacion)
    {
        var cartera = await carteras.ValidarAsync(solicitud.IdCartera, cancelacion);
        if (cartera is null)
        {
            return Problem(
                statusCode: StatusCodes.Status403Forbidden,
                title: "No tienes acceso a la cartera seleccionada.");
        }

        var claims = User.Claims
            .Where(c => c.Type is not ClaimsBabel.IdCartera and not ClaimsBabel.Cartera)
            .ToList();
        claims.Add(new Claim(ClaimsBabel.IdCartera, cartera.IdCartera.ToString()));
        claims.Add(new Claim(ClaimsBabel.Cartera, cartera.Nombre));

        var identidad = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);
        await HttpContext.SignInAsync(
            CookieAuthenticationDefaults.AuthenticationScheme,
            new ClaimsPrincipal(identidad));

        return Ok(new CarteraSesionResponse(cartera.IdCartera, cartera.Nombre));
    }
}
