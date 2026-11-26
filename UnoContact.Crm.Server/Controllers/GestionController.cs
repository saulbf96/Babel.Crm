using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using UnoContact.Crm.Application.Gestion;

namespace UnoContact.Crm.Server.Controllers;

/// <summary>
/// Gestión de cartera. Equivale al flujo principal de FRM_GESTION_CARTERA:
/// localizar cuenta, ver teléfonos/demográficos/historial y registrar gestión o promesa.
/// La cartera siempre se toma de la sesión; nunca del cliente.
/// </summary>
[ApiController]
[Route("api/gestion")]
[Authorize(Policy = "Gestion")]
public sealed class GestionController(IServicioGestion servicio) : ControllerBase
{
    [HttpGet("tipos")]
    public async Task<ActionResult<IReadOnlyList<TipoGestionDto>>> Tipos(CancellationToken cancelacion)
    {
        var tipos = await servicio.ConsultarTiposAsync(cancelacion);
        return Ok(tipos);
    }

    [HttpGet("cuentas")]
    public async Task<ActionResult<IReadOnlyList<CuentaResumen>>> ConsultarCuentas(
        [FromQuery] string? texto, CancellationToken cancelacion)
    {
        var cuentas = await servicio.ConsultarCuentasAsync(texto, cancelacion);
        return Ok(cuentas);
    }

    [HttpPost("cuentas")]
    public async Task<ActionResult<ResultadoCuenta>> CrearCuenta(
        SolicitudCuenta solicitud, CancellationToken cancelacion)
    {
        var resultado = await servicio.CrearCuentaAsync(solicitud, cancelacion);
        return Ok(resultado);
    }

    [HttpGet("cuentas/{idCuenta:long}")]
    public async Task<ActionResult<CuentaDetalle>> ConsultarCuenta(
        long idCuenta, CancellationToken cancelacion)
    {
        var cuenta = await servicio.ConsultarCuentaAsync(idCuenta, cancelacion);
        return cuenta is null ? NotFound() : Ok(cuenta);
    }

    [HttpGet("cuentas/{idCuenta:long}/telefonos")]
    public async Task<ActionResult<IReadOnlyList<TelefonoResumen>>> Telefonos(
        long idCuenta, CancellationToken cancelacion)
    {
        var telefonos = await servicio.ConsultarTelefonosAsync(idCuenta, cancelacion);
        return Ok(telefonos);
    }

    [HttpPost("cuentas/{idCuenta:long}/telefonos")]
    public async Task<ActionResult<ResultadoOperacion>> RegistrarTelefono(
        long idCuenta, SolicitudTelefono solicitud, CancellationToken cancelacion)
    {
        var resultado = await servicio.RegistrarTelefonoAsync(idCuenta, solicitud, cancelacion);
        return Ok(resultado);
    }

    [HttpGet("cuentas/{idCuenta:long}/gestiones")]
    public async Task<ActionResult<IReadOnlyList<GestionResumen>>> Gestiones(
        long idCuenta, CancellationToken cancelacion)
    {
        var gestiones = await servicio.ConsultarGestionesAsync(idCuenta, cancelacion);
        return Ok(gestiones);
    }

    [HttpPost("cuentas/{idCuenta:long}/gestiones")]
    public async Task<ActionResult<ResultadoOperacion>> RegistrarGestion(
        long idCuenta, SolicitudGestion solicitud, CancellationToken cancelacion)
    {
        var resultado = await servicio.RegistrarGestionAsync(
            solicitud with { IdCuenta = idCuenta }, cancelacion);
        return Ok(resultado);
    }

    [HttpGet("cuentas/{idCuenta:long}/promesas")]
    public async Task<ActionResult<IReadOnlyList<PromesaResumen>>> Promesas(
        long idCuenta, CancellationToken cancelacion)
    {
        var promesas = await servicio.ConsultarPromesasAsync(idCuenta, cancelacion);
        return Ok(promesas);
    }

    [HttpPost("cuentas/{idCuenta:long}/promesas")]
    public async Task<ActionResult<ResultadoOperacion>> RegistrarPromesa(
        long idCuenta, SolicitudPromesa solicitud, CancellationToken cancelacion)
    {
        var resultado = await servicio.RegistrarPromesaAsync(
            solicitud with { IdCuenta = idCuenta }, cancelacion);
        return Ok(resultado);
    }

    [HttpGet("cuentas/{idCuenta:long}/demograficos")]
    public async Task<ActionResult<IReadOnlyList<DemograficoResumen>>> Demograficos(
        long idCuenta, CancellationToken cancelacion)
    {
        var demograficos = await servicio.ConsultarDemograficosAsync(idCuenta, cancelacion);
        return Ok(demograficos);
    }
}
