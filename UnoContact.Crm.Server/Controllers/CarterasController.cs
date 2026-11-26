using UnoContact.Crm.Server.Infraestructura;
using UnoContact.Crm.Application.Carteras;
using UnoContact.Crm.Application.Catalogos;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace UnoContact.Crm.Server.Controllers;

public sealed record AsignarPersonalRequest(
    IReadOnlyList<int>? IdsEmpleados,
    byte? IdDepartamento,
    bool Operativo);

public sealed record RestaurarPersonalRequest(IReadOnlyList<int>? IdsEmpleados);

/// <summary>
/// Carteras, cambio de cartera y asignación de personal
/// (equivale a FRM_CONSULTA_BASE y FRM_ASIGNARPERSONAL).
/// </summary>
[ApiController]
[Route("api/carteras")]
[Authorize]
public sealed class CarterasController(IServicioCarteras servicio) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<CarteraDto>>> Consultar(CancellationToken cancelacion)
    {
        var carteras = await servicio.ConsultarAsync(cancelacion);
        return Ok(carteras);
    }

    [HttpGet("{idCartera}/personal")]
    [Permiso("asignar-personal")]
    public async Task<ActionResult<IReadOnlyList<PersonalCartera>>> Personal(
        byte idCartera,
        [FromQuery] string? texto,
        CancellationToken cancelacion)
    {
        var personal = await servicio.ConsultarPersonalAsync(idCartera, texto, cancelacion);
        return Ok(personal);
    }

    [HttpPost("{idCartera}/asignar")]
    [Permiso("asignar-personal")]
    public async Task<ActionResult<ResultadoAsignacion>> Asignar(
        byte idCartera,
        AsignarPersonalRequest solicitud,
        CancellationToken cancelacion)
    {
        var peticion = new SolicitudAsignacionPersonal(
            solicitud.IdsEmpleados ?? [],
            idCartera,
            solicitud.IdDepartamento,
            solicitud.Operativo);

        var resultado = await servicio.AsignarAsync(peticion, cancelacion);
        return Ok(resultado);
    }



    [HttpPost("restaurar")]
    [Permiso("asignar-personal")]
    public async Task<ActionResult<ResultadoRestauracion>> Restaurar(
        RestaurarPersonalRequest solicitud,
        CancellationToken cancelacion)
    {
        var resultado = await servicio.RestaurarAsync(solicitud.IdsEmpleados ?? [], cancelacion);
        return Ok(resultado);
    }

    [HttpGet("operativo")]
    [Permiso("asignar-personal")]
    public async Task<ActionResult<IReadOnlyList<OperativoResumen>>> Operativo(
        [FromQuery] int? idEmpleado,
        [FromQuery] byte? idCartera,
        CancellationToken cancelacion)
    {
        var operativo = await servicio.ConsultarOperativoAsync(idEmpleado, idCartera, cancelacion);
        return Ok(operativo);
    }
}
