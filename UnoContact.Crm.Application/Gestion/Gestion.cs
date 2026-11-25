using System.ComponentModel.DataAnnotations;

namespace UnoContact.Crm.Application.Gestion;

/// <summary>Cuenta de la cartera activa (equivalente al ID CONTROL del escritorio).</summary>
public sealed record CuentaResumen(
    long IdCuenta,
    byte IdCartera,
    string Cartera,
    int IdControlLegacy,
    string NumeroCuenta,
    string? NombreCliente,
    string? SituacionCuenta,
    string? RazonMora,
    decimal? Saldo,
    string? Empleado,
    bool Activo,
    DateTime FechaRegistro);

public sealed record CuentaDetalle(
    long IdCuenta,
    byte IdCartera,
    string Cartera,
    int IdControlLegacy,
    string NumeroCuenta,
    string? NombreCliente,
    string? SituacionCuenta,
    string? RazonMora,
    decimal? Saldo,
    byte IdSegmento,
    byte IdProducto,
    byte IdCampana,
    bool Activo,
    DateTime FechaRegistro);

public sealed record TelefonoResumen(
    long IdTelefono,
    string Numero,
    string? Tipo,
    byte? Calificacion,
    string? Origen,
    bool Activo,
    DateTime FechaRegistro);

public sealed record TipoGestionDto(byte IdTipoGestion, string Nombre);

public sealed record GestionResumen(
    long IdGestion,
    byte IdTipoGestion,
    string TipoGestion,
    string? Comentario,
    string? TelefonoMarcado,
    bool Inbound,
    DateTime FechaInicio,
    DateTime? FechaFin,
    int? TiempoLlamadaSegundos,
    int? TiempoEscrituraSegundos,
    string? Empleado);

public sealed record PromesaResumen(
    long IdPromesa,
    decimal Monto,
    DateOnly FechaPromesa,
    string? LugarPago,
    string? FuenteIngreso,
    string? RazonMora,
    string? Notas,
    string Estatus,
    long? IdGestion,
    DateTime FechaRegistro);

public sealed record DemograficoResumen(
    long IdDemografico,
    string? Calle,
    string? Colonia,
    string? CodigoPostal,
    string? Delegacion,
    string? Estado,
    string? Telefono,
    string? Email,
    DateTime FechaRegistro);

public sealed record SolicitudCuenta(
    [Range(1, int.MaxValue)] int IdControlLegacy,
    [Required][StringLength(50)] string NumeroCuenta,
    [StringLength(200)] string? NombreCliente,
    [StringLength(50)] string? SituacionCuenta,
    [StringLength(100)] string? RazonMora,
    [Range(0, double.MaxValue)] decimal? Saldo);

public sealed record ResultadoCuenta(long IdCuenta, string Mensaje);

public sealed record SolicitudTelefono(
    [Required][StringLength(30)] string Numero,
    [StringLength(20)] string? Tipo,
    [Range(0, 255)] byte? Calificacion,
    [StringLength(50)] string? Origen);

public sealed record SolicitudGestion(
    [Range(1, long.MaxValue)] long IdCuenta,
    [Range(1, 255)] byte IdTipoGestion,
    [StringLength(4000)] string? Comentario,
    long? IdTelefono,
    [StringLength(30)] string? TelefonoMarcado,
    bool Inbound,
    int? TiempoLlamadaSegundos,
    int? TiempoEscrituraSegundos);

public sealed record SolicitudPromesa(
    [Range(1, long.MaxValue)] long IdCuenta,
    long? IdGestion,
    [Range(0.01, double.MaxValue)] decimal Monto,
    DateOnly FechaPromesa,
    [StringLength(100)] string? LugarPago,
    [StringLength(100)] string? FuenteIngreso,
    [StringLength(100)] string? RazonMora,
    [StringLength(4000)] string? Notas);

public sealed record ResultadoOperacion(long Id, string Mensaje);

public interface IRepositorioGestion
{
    Task<IReadOnlyList<TipoGestionDto>> ConsultarTiposAsync(CancellationToken cancelacion = default);

    Task<IReadOnlyList<CuentaResumen>> ConsultarCuentasAsync(
        byte idCartera, string? texto, CancellationToken cancelacion = default);

    Task<ResultadoCuenta> CrearCuentaAsync(
        SolicitudCuenta solicitud, byte idCartera, int? idEmpleado, string usuario,
        CancellationToken cancelacion = default);

    Task<CuentaDetalle?> ConsultarCuentaAsync(
        byte idCartera, long idCuenta, CancellationToken cancelacion = default);

    Task<IReadOnlyList<TelefonoResumen>> ConsultarTelefonosAsync(
        byte idCartera, long idCuenta, CancellationToken cancelacion = default);

    Task<ResultadoOperacion> RegistrarTelefonoAsync(
        SolicitudTelefono solicitud, byte idCartera, long idCuenta, string usuario,
        CancellationToken cancelacion = default);

    Task<IReadOnlyList<GestionResumen>> ConsultarGestionesAsync(
        byte idCartera, long idCuenta, CancellationToken cancelacion = default);

    Task<ResultadoOperacion> RegistrarGestionAsync(
        SolicitudGestion solicitud, byte idCartera, int idEmpleado, string usuario,
        CancellationToken cancelacion = default);

    Task<IReadOnlyList<PromesaResumen>> ConsultarPromesasAsync(
        byte idCartera, long idCuenta, CancellationToken cancelacion = default);

    Task<ResultadoOperacion> RegistrarPromesaAsync(
        SolicitudPromesa solicitud, byte idCartera, string usuario,
        CancellationToken cancelacion = default);

    Task<IReadOnlyList<DemograficoResumen>> ConsultarDemograficosAsync(
        byte idCartera, long idCuenta, CancellationToken cancelacion = default);
}

public interface IServicioGestion
{
    Task<IReadOnlyList<TipoGestionDto>> ConsultarTiposAsync(CancellationToken cancelacion = default);

    Task<IReadOnlyList<CuentaResumen>> ConsultarCuentasAsync(
        string? texto, CancellationToken cancelacion = default);

    Task<ResultadoCuenta> CrearCuentaAsync(
        SolicitudCuenta solicitud, CancellationToken cancelacion = default);

    Task<CuentaDetalle?> ConsultarCuentaAsync(
        long idCuenta, CancellationToken cancelacion = default);

    Task<IReadOnlyList<TelefonoResumen>> ConsultarTelefonosAsync(
        long idCuenta, CancellationToken cancelacion = default);

    Task<ResultadoOperacion> RegistrarTelefonoAsync(
        long idCuenta, SolicitudTelefono solicitud, CancellationToken cancelacion = default);

    Task<IReadOnlyList<GestionResumen>> ConsultarGestionesAsync(
        long idCuenta, CancellationToken cancelacion = default);

    Task<ResultadoOperacion> RegistrarGestionAsync(
        SolicitudGestion solicitud, CancellationToken cancelacion = default);

    Task<IReadOnlyList<PromesaResumen>> ConsultarPromesasAsync(
        long idCuenta, CancellationToken cancelacion = default);

    Task<ResultadoOperacion> RegistrarPromesaAsync(
        SolicitudPromesa solicitud, CancellationToken cancelacion = default);

    Task<IReadOnlyList<DemograficoResumen>> ConsultarDemograficosAsync(
        long idCuenta, CancellationToken cancelacion = default);
}
