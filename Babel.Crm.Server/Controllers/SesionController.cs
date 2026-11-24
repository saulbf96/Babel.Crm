using Babel.Crm.Application.Sesion;
using Microsoft.AspNetCore.Mvc;

namespace Babel.Crm.Server.Controllers;

/// <summary>Sesión del usuario autenticado por Active Directory: perfiles y menú.</summary>
[ApiController]
[Route("api/sesion")]
public sealed class SesionController(IServicioSesion servicio) : ControllerBase
{
    [HttpGet]
    public ActionResult<SesionDto> Get() => servicio.ObtenerSesion();
}
