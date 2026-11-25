using UnoContact.Crm.Application.Rh;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace UnoContact.Crm.Server.Controllers;

/// <summary>
/// Pantallas "Consulta Empleados" y "Alta de empleados"
/// (equivalen a FRM_CONSULTAEMPLEADOS y FRM_ALTAEMPLEADOS de BABEL ADMINISTRATIVO).
/// Solo perfil Administrador por ahora ("Por confirmar con usuarios").
/// </summary>
[ApiController]
[Route("api/empleados")]
[Authorize(Policy = "Administrador")]
public sealed class EmpleadosController(IServicioEmpleados servicio) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<EmpleadoResumen>>> Consultar(
        [FromQuery] byte? idCartera,
        [FromQuery] string? nombre,
        [FromQuery] byte? idPuesto,
        [FromQuery] bool soloActivos = true,
        CancellationToken cancelacion = default)
    {
        var filtro = new FiltroEmpleados(idCartera, nombre, idPuesto, soloActivos);
        var empleados = await servicio.ConsultarAsync(filtro, cancelacion);
        return Ok(empleados);
    }

    [HttpPost]
    public async Task<ActionResult<ResultadoAltaEmpleado>> Alta(
        SolicitudAltaEmpleado solicitud,
        CancellationToken cancelacion)
    {
        var resultado = await servicio.AltaAsync(solicitud, cancelacion);
        return Ok(resultado);
    }
}
