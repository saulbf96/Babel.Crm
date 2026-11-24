using Babel.Crm.Application.Rh;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Babel.Crm.Server.Controllers;

/// <summary>
/// Pantalla "Consulta Empleados" (equivale a FRM_CONSULTAEMPLEADOS de BABEL ADMINISTRATIVO).
/// Solo perfil Administrador por ahora ("Por confirmar con usuarios").
/// </summary>
[ApiController]
[Route("api/empleados")]
[Authorize(Policy = "Administrador")]
public sealed class EmpleadosController(IServicioEmpleados servicio) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<EmpleadoResumen>>> Consultar(
        [FromQuery] int? idCliente,
        [FromQuery] string? nombre,
        [FromQuery] byte? idPuesto,
        [FromQuery] bool soloActivos = true,
        CancellationToken cancelacion = default)
    {
        var filtro = new FiltroEmpleados(idCliente, nombre, idPuesto, soloActivos);
        var empleados = await servicio.ConsultarAsync(filtro, cancelacion);
        return Ok(empleados);
    }
}
