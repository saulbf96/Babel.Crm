using UnoContact.Crm.Application.Sesion;
using Microsoft.AspNetCore.Mvc;

namespace UnoContact.Crm.Server.Controllers;

/// <summary>Sesión del usuario autenticado con usuario y contraseña del CRM: perfiles y menú.</summary>
[ApiController]
[Route("api/sesion")]
public sealed class SesionController(IServicioSesion servicio) : ControllerBase
{
    [HttpGet]
    public ActionResult<SesionDto> Get() => servicio.ObtenerSesion();
}
