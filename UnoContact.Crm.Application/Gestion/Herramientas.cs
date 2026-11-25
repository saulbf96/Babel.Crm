using System.ComponentModel.DataAnnotations;

namespace UnoContact.Crm.Application.Gestion;

/// <summary>Nota de seguimiento de FRM_NOTAS (CONSULTA_CANT_NOTAS / INSERTA_CANT_NOTAS).</summary>
public sealed record NotaResumen(
    long IdNota,
    string TipoSeguimiento,
    DateTime FechaSeguimiento,
    string? Telefono,
    int? Pagos,
    decimal? Importe,
    string? Texto,
    DateTime FechaRegistro,
    string? Empleado);

public sealed record SolicitudNota(
    long IdCuenta,
    [StringLength(30)] string? TipoSeguimiento,
    DateTime? FechaSeguimiento,
    [StringLength(30)] string? Telefono,
    [Range(0, int.MaxValue)] int? Pagos,
    [Range(0, double.MaxValue)] decimal? Importe,
    [StringLength(4000)] string? Texto);

/// <summary>Bloc de notas del ejecutivo (CONSULTA_NEBN_BLOC_NOTAS).</summary>
public sealed record BlocNotaDto(string Texto, DateTime? FechaRegistro);

/// <summary>Control de recesos/break del legacy (FRM_BLOQUEAR), no bloqueo de cuenta.</summary>
public sealed record RecesoResumen(
    long IdReceso, string? TipoReceso, DateTime Inicio, DateTime? Fin, int? Minutos);

public sealed record RecesoActivo(long IdReceso, DateTime Inicio, string Mensaje);

/// <summary>Agenda de llamadas (FRM_AGENDAR, inactivo en el legacy; habilitado en el CRM).</summary>
public sealed record AgendaResumen(
    long IdAgenda,
    long IdCuenta,
    string NumeroCuenta,
    string? NombreCliente,
    DateTime FechaHora,
    string? Telefono,
    string? Asunto,
    string Estatus,
    string? Empleado);

public sealed record SolicitudAgenda(
    long IdCuenta,
    DateTime FechaHora,
    [StringLength(30)] string? Telefono,
    [StringLength(200)] string? Asunto);

/// <summary>Simulador de descuentos y planes de pago (FRM_NEGOCIACIONES / "Calculadora").</summary>
public sealed record NegociacionResumen(
    long IdNegociacion,
    string? TipoNegociacion,
    string? TipoPago,
    decimal MontoOriginal,
    decimal PorcentajeDescuento,
    decimal MontoFinal,
    int NumeroPagos,
    DateOnly? FechaPrimerPago,
    string? Comentario,
    DateTime FechaRegistro,
    string? Empleado);

public sealed record SolicitudNegociacion(
    long IdCuenta,
    [StringLength(50)] string? TipoNegociacion,
    [StringLength(50)] string? TipoPago,
    [Range(0.01, double.MaxValue)] decimal MontoOriginal,
    [Range(0, 100)] decimal PorcentajeDescuento,
    [Range(0.01, double.MaxValue)] decimal MontoFinal,
    [Range(1, 360)] int NumeroPagos,
    DateOnly? FechaPrimerPago,
    [StringLength(4000)] string? Comentario);

public sealed record SolicitudActualizaDemografico(
    long IdCuenta,
    [StringLength(200)] string? Calle,
    [StringLength(150)] string? Colonia,
    [StringLength(10)] string? CodigoPostal,
    [StringLength(150)] string? Delegacion,
    [StringLength(100)] string? Estado,
    [StringLength(30)] string? Telefono,
    [StringLength(150)] string? Email);

public interface IRepositorioHerramientas
{
    Task<IReadOnlyList<NotaResumen>> ConsultarNotasAsync(byte idCartera, long idCuenta, CancellationToken cancelacion = default);
    Task<ResultadoOperacion> RegistrarNotaAsync(SolicitudNota solicitud, byte idCartera, int idEmpleado, CancellationToken cancelacion = default);

    Task<BlocNotaDto> ConsultarBlocNotaAsync(byte idCartera, int idEmpleado, CancellationToken cancelacion = default);
    Task<ResultadoOperacion> GuardarBlocNotaAsync(byte idCartera, int idEmpleado, string texto, CancellationToken cancelacion = default);

    Task<RecesoActivo> IniciarRecesoAsync(byte idCartera, int idEmpleado, string tipoReceso, CancellationToken cancelacion = default);
    Task<ResultadoOperacion> FinalizarRecesoAsync(long idReceso, byte idCartera, int idEmpleado, CancellationToken cancelacion = default);
    Task<IReadOnlyList<RecesoResumen>> ConsultarRecesosAsync(byte idCartera, int idEmpleado, CancellationToken cancelacion = default);

    Task<IReadOnlyList<AgendaResumen>> ConsultarAgendaAsync(byte idCartera, long? idCuenta, CancellationToken cancelacion = default);
    Task<ResultadoOperacion> RegistrarAgendaAsync(SolicitudAgenda solicitud, byte idCartera, int idEmpleado, CancellationToken cancelacion = default);
    Task<ResultadoOperacion> CambiarEstatusAgendaAsync(long idAgenda, byte idCartera, string estatus, CancellationToken cancelacion = default);

    Task<IReadOnlyList<NegociacionResumen>> ConsultarNegociacionesAsync(byte idCartera, long idCuenta, CancellationToken cancelacion = default);
    Task<ResultadoOperacion> RegistrarNegociacionAsync(SolicitudNegociacion solicitud, byte idCartera, int idEmpleado, CancellationToken cancelacion = default);

    Task<ResultadoOperacion> ActualizarDemograficoAsync(
        SolicitudActualizaDemografico solicitud, byte idCartera, string usuario, CancellationToken cancelacion = default);
}

public interface IServicioHerramientas
{
    Task<IReadOnlyList<NotaResumen>> ConsultarNotasAsync(long idCuenta, CancellationToken cancelacion = default);
    Task<ResultadoOperacion> RegistrarNotaAsync(SolicitudNota solicitud, CancellationToken cancelacion = default);

    Task<BlocNotaDto> ConsultarBlocNotaAsync(CancellationToken cancelacion = default);
    Task<ResultadoOperacion> GuardarBlocNotaAsync(string texto, CancellationToken cancelacion = default);

    Task<RecesoActivo> IniciarRecesoAsync(string tipoReceso, CancellationToken cancelacion = default);
    Task<ResultadoOperacion> FinalizarRecesoAsync(long idReceso, CancellationToken cancelacion = default);
    Task<IReadOnlyList<RecesoResumen>> ConsultarRecesosAsync(CancellationToken cancelacion = default);

    Task<IReadOnlyList<AgendaResumen>> ConsultarAgendaAsync(long? idCuenta, CancellationToken cancelacion = default);
    Task<ResultadoOperacion> RegistrarAgendaAsync(SolicitudAgenda solicitud, CancellationToken cancelacion = default);
    Task<ResultadoOperacion> CambiarEstatusAgendaAsync(long idAgenda, string estatus, CancellationToken cancelacion = default);

    Task<IReadOnlyList<NegociacionResumen>> ConsultarNegociacionesAsync(long idCuenta, CancellationToken cancelacion = default);
    Task<ResultadoOperacion> RegistrarNegociacionAsync(SolicitudNegociacion solicitud, CancellationToken cancelacion = default);

    Task<ResultadoOperacion> ActualizarDemograficoAsync(
        SolicitudActualizaDemografico solicitud, CancellationToken cancelacion = default);
}
