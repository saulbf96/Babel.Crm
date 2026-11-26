using UnoContact.Crm.Server.Infraestructura;
using UnoContact.Crm.Application.Rh;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace UnoContact.Crm.Server.Controllers;

/// <summary>
/// Pantalla "Bajas de personal" (reemplaza FRM_BAJAPERSONAL de BABEL ADMINISTRATIVO).
/// Baja lógica del empleado + su usuario, dentro de la cartera activa de la sesión.
/// </summary>
[ApiController]
[Route("api/bajas")]
[Permiso("bajas")]
public sealed class BajasController(IServicioBajas servicio, ILogger<BajasController> bitacora) : ControllerBase
{
    [HttpGet("causas")]
    public async Task<ActionResult<IReadOnlyList<CausaBaja>>> Causas(CancellationToken cancelacion) =>
        Ok(await servicio.CausasAsync(cancelacion));

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<EmpleadoBaja>>> Consultar(
        [FromQuery] string? nombre,
        [FromQuery] EstatusBaja estatus = EstatusBaja.Activos,
        CancellationToken cancelacion = default) =>
        Ok(await servicio.ConsultarAsync(nombre, estatus, cancelacion));

    [HttpPost("{idEmpleado:int}")]
    public async Task<ActionResult<ResultadoBaja>> DarDeBaja(int idEmpleado, SolicitudBaja solicitud, CancellationToken cancelacion)
    {
        var resultado = await servicio.DarDeBajaAsync(idEmpleado, solicitud, cancelacion);
        bitacora.LogInformation("Baja del empleado {IdEmpleado} por {Usuario} (causa {IdCausa})",
            idEmpleado, User.Identity?.Name, solicitud.IdCausaBaja);
        return Ok(resultado);
    }

    [HttpPost("{idEmpleado:int}/reactivar")]
    public async Task<IActionResult> Reactivar(int idEmpleado, SolicitudReactivacion solicitud, CancellationToken cancelacion)
    {
        await servicio.ReactivarAsync(idEmpleado, solicitud, cancelacion);
        bitacora.LogInformation("Reactivación del empleado {IdEmpleado} por {Usuario}", idEmpleado, User.Identity?.Name);
        return NoContent();
    }
}
