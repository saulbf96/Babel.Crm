using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using UnoContact.Crm.Application.Gestion;

namespace UnoContact.Crm.Server.Controllers;

/// <summary>
/// Herramientas del FRM_GESTION_CARTERA. La cartera y el empleado se toman de la
/// sesión en IServicioHerramientas; el cliente nunca los envía.
/// </summary>
[ApiController]
[Route("api/herramientas")]
[Authorize(Policy = "Gestion")]
public sealed class HerramientasController(IServicioHerramientas servicio) : ControllerBase
{
    // --- Notas (F7) ---
    [HttpGet("notas/{idCuenta:long}")]
    public async Task<ActionResult<IReadOnlyList<NotaResumen>>> Notas(
        long idCuenta, CancellationToken cancelacion) =>
        Ok(await servicio.ConsultarNotasAsync(idCuenta, cancelacion));

    [HttpPost("notas/{idCuenta:long}")]
    public async Task<ActionResult<ResultadoOperacion>> RegistrarNota(
        long idCuenta, SolicitudNota solicitud, CancellationToken cancelacion) =>
        Ok(await servicio.RegistrarNotaAsync(solicitud with { IdCuenta = idCuenta }, cancelacion));

    // --- Bloc de notas (F8) ---
    [HttpGet("bloc-nota")]
    public async Task<ActionResult<BlocNotaDto>> BlocNota(CancellationToken cancelacion) =>
        Ok(await servicio.ConsultarBlocNotaAsync(cancelacion));

    [HttpPut("bloc-nota")]
    public async Task<ActionResult<ResultadoOperacion>> GuardarBlocNota(
        [FromBody] GuardarTextoDto solicitud, CancellationToken cancelacion) =>
        Ok(await servicio.GuardarBlocNotaAsync(solicitud.Texto ?? string.Empty, cancelacion));

    // --- Bloquear = receso/break (Ctrl+B) ---
    [HttpGet("recesos")]
    public async Task<ActionResult<IReadOnlyList<RecesoResumen>>> Recesos(CancellationToken cancelacion) =>
        Ok(await servicio.ConsultarRecesosAsync(cancelacion));

    [HttpPost("recesos")]
    public async Task<ActionResult<RecesoActivo>> IniciarReceso(
        [FromBody] GuardarTextoDto solicitud, CancellationToken cancelacion) =>
        Ok(await servicio.IniciarRecesoAsync(solicitud.Texto ?? "Receso", cancelacion));

    [HttpPost("recesos/{idReceso:long}/fin")]
    public async Task<ActionResult<ResultadoOperacion>> FinalizarReceso(
        long idReceso, CancellationToken cancelacion) =>
        Ok(await servicio.FinalizarRecesoAsync(idReceso, cancelacion));

    // --- Agendar llamada (Ctrl+A en el legacy, habilitado en el CRM) ---
    [HttpGet("agenda")]
    public async Task<ActionResult<IReadOnlyList<AgendaResumen>>> Agenda(
        [FromQuery] long? idCuenta, CancellationToken cancelacion) =>
        Ok(await servicio.ConsultarAgendaAsync(idCuenta, cancelacion));

    [HttpPost("agenda")]
    public async Task<ActionResult<ResultadoOperacion>> RegistrarAgenda(
        SolicitudAgenda solicitud, CancellationToken cancelacion) =>
        Ok(await servicio.RegistrarAgendaAsync(solicitud, cancelacion));

    [HttpPost("agenda/{idAgenda:long}/estatus")]
    public async Task<ActionResult<ResultadoOperacion>> CambiarEstatusAgenda(
        long idAgenda, [FromBody] GuardarTextoDto solicitud, CancellationToken cancelacion) =>
        Ok(await servicio.CambiarEstatusAgendaAsync(idAgenda, solicitud.Texto ?? "PENDIENTE", cancelacion));

    // --- Calculadora = FRM_NEGOCIACIONES (F9) ---
    [HttpGet("negociaciones/{idCuenta:long}")]
    public async Task<ActionResult<IReadOnlyList<NegociacionResumen>>> Negociaciones(
        long idCuenta, CancellationToken cancelacion) =>
        Ok(await servicio.ConsultarNegociacionesAsync(idCuenta, cancelacion));

    [HttpPost("negociaciones/{idCuenta:long}")]
    public async Task<ActionResult<ResultadoOperacion>> RegistrarNegociacion(
        long idCuenta, SolicitudNegociacion solicitud, CancellationToken cancelacion) =>
        Ok(await servicio.RegistrarNegociacionAsync(solicitud with { IdCuenta = idCuenta }, cancelacion));

    // --- Actualiza información (F10) ---
    [HttpPut("demograficos/{idCuenta:long}")]
    public async Task<ActionResult<ResultadoOperacion>> ActualizarDemografico(
        long idCuenta, SolicitudActualizaDemografico solicitud, CancellationToken cancelacion) =>
        Ok(await servicio.ActualizarDemograficoAsync(solicitud with { IdCuenta = idCuenta }, cancelacion));
}

/// <summary>Cuerpo simple para acciones que solo necesitan un texto (bloc, receso, estatus).</summary>
public sealed record GuardarTextoDto(string? Texto);
