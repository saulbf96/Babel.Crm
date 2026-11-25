using UnoContact.Crm.Application.Adm;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace UnoContact.Crm.Server.Controllers;

/// <summary>
/// Carga de asignaciones (staging). El procesamiento real del .exe sigue pendiente
/// hasta descifrar ADMINISTRA_APP.PROCESO_ASIGNACION y confirmar el layout del Excel.
/// </summary>
[ApiController]
[Route("api/cargas")]
[Authorize(Policy = "Administrador")]
public sealed class CargasController(IServicioCargas servicio) : ControllerBase
{
    [HttpGet("procesos")]
    public async Task<ActionResult<IReadOnlyList<ProcesoAsignacionDto>>> Procesos(CancellationToken cancelacion)
    {
        var procesos = await servicio.ConsultarProcesosAsync(cancelacion);
        return Ok(procesos);
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<CargaAsignacionResumen>>> Consultar(
        [FromQuery] byte? idCartera,
        CancellationToken cancelacion)
    {
        var cargas = await servicio.ConsultarAsync(idCartera, cancelacion);
        return Ok(cargas);
    }

    [HttpPost]
    public async Task<ActionResult<ResultadoCargaAsignacion>> Crear(
        SolicitudCargaAsignacion solicitud,
        CancellationToken cancelacion)
    {
        var resultado = await servicio.CrearAsync(solicitud, cancelacion);
        return Ok(resultado);
    }
}
