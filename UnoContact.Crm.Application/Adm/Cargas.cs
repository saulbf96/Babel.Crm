using System.ComponentModel.DataAnnotations;

namespace UnoContact.Crm.Application.Adm;

public sealed record ProcesoAsignacionDto(byte IdProceso, string Nombre, string? Descripcion);

public sealed record CargaAsignacionResumen(
    int IdCarga,
    byte IdCartera,
    string Cartera,
    byte Proceso,
    string ProcesoNombre,
    string NombreArchivo,
    string Estatus,
    int TotalRegistros,
    int Procesados,
    int Errores,
    string? Mensaje,
    string? Usuario,
    DateTime FechaInicio,
    DateTime? FechaFin);

public sealed record SolicitudCargaAsignacion(
    [Range(1, 255, ErrorMessage = "Selecciona una cartera.")]
    byte IdCartera,
    [Range(1, 255, ErrorMessage = "Selecciona un proceso.")]
    byte Proceso,
    [Required(ErrorMessage = "El archivo es obligatorio.")]
    [StringLength(260, ErrorMessage = "El nombre del archivo no puede pasar de 260 caracteres.")]
    string NombreArchivo,
    string? RutaArchivo = null,
    IReadOnlyList<string>? Filas = null);

public sealed record ResultadoCargaAsignacion(int IdCarga, int Filas, string Mensaje);

public interface IRepositorioCargas
{
    Task<IReadOnlyList<ProcesoAsignacionDto>> ConsultarProcesosAsync(CancellationToken cancelacion = default);

    Task<IReadOnlyList<CargaAsignacionResumen>> ConsultarAsync(
        byte? idCartera, CancellationToken cancelacion = default);

    Task<ResultadoCargaAsignacion> CrearAsync(
        SolicitudCargaAsignacion solicitud, int idUsuario, string usuario, CancellationToken cancelacion = default);
}

public interface IServicioCargas
{
    Task<IReadOnlyList<ProcesoAsignacionDto>> ConsultarProcesosAsync(CancellationToken cancelacion = default);

    Task<IReadOnlyList<CargaAsignacionResumen>> ConsultarAsync(
        byte? idCartera, CancellationToken cancelacion = default);

    Task<ResultadoCargaAsignacion> CrearAsync(
        SolicitudCargaAsignacion solicitud, CancellationToken cancelacion = default);
}
