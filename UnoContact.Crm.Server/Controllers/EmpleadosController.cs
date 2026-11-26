using UnoContact.Crm.Server.Infraestructura;
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
[Authorize]
public sealed class EmpleadosController(IServicioEmpleados servicio) : ControllerBase
{
    [HttpGet]
    [Permiso("empleados")]
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
    [Permiso("alta-empleados")]
    public async Task<ActionResult<ResultadoAltaEmpleado>> Alta(
        SolicitudAltaEmpleado solicitud,
        CancellationToken cancelacion)
    {
        var resultado = await servicio.AltaAsync(solicitud, cancelacion);
        return Ok(resultado);
    }

    /// <summary>Da acceso a la cartera activa a un empleado que ya existe (en lugar de darlo de alta otra vez).</summary>
    [HttpPost("{idEmpleado:int}/acceso-cartera")]
    [Permiso("alta-empleados")]
    public async Task<IActionResult> DarAccesoCartera(int idEmpleado, CancellationToken cancelacion)
    {
        await servicio.DarAccesoCarteraAsync(idEmpleado, cancelacion);
        return NoContent();
    }

    /// <summary>Historial de altas de la cartera de la sesión. Sin fechas: semana actual.</summary>
    [HttpGet("altas")]
    [Permiso("alta-empleados")]
    public async Task<ActionResult<IReadOnlyList<AltaRegistrada>>> Altas(
        [FromQuery] DateOnly? desde,
        [FromQuery] DateOnly? hasta,
        CancellationToken cancelacion) =>
        Ok(await servicio.ConsultarAltasAsync(desde, hasta, cancelacion));

    /// <summary>Edita nombre, puesto, sexo y horario (NUEVO: BABEL no tenía edición de empleados).</summary>
    [HttpPut("{idEmpleado:int}")]
    [Permiso("empleados")]
    public async Task<IActionResult> Editar(int idEmpleado, SolicitudEdicionEmpleado solicitud, CancellationToken cancelacion)
    {
        await servicio.EditarAsync(idEmpleado, solicitud, cancelacion);
        return NoContent();
    }

    /// <summary>Permisos actuales del empleado (para la sección Permisos de Editar).</summary>
    [HttpGet("{idEmpleado:int}/permisos")]
    [Permiso("empleados")]
    public async Task<ActionResult<PermisosEmpleado>> Permisos(int idEmpleado, CancellationToken cancelacion) =>
        Ok(await servicio.ConsultarPermisosAsync(idEmpleado, cancelacion));
}
