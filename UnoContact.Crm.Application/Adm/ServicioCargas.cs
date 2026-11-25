using UnoContact.Crm.Application.Abstracciones;

namespace UnoContact.Crm.Application.Adm;

/// <summary>
/// Carga de asignaciones en modo staging. El proceso real del .exe
/// (ADMINISTRA_APP.PROCESO_ASIGNACION) sigue pendiente de descifrar.
/// </summary>
public sealed class ServicioCargas(
    IRepositorioCargas repositorio,
    IUsuarioActual usuario) : IServicioCargas
{
    /// <summary>Límite defensivo para no guardar archivos enormes en la base.</summary>
    public const int MaximoFilas = 5000;

    public Task<IReadOnlyList<ProcesoAsignacionDto>> ConsultarProcesosAsync(CancellationToken cancelacion = default) =>
        repositorio.ConsultarProcesosAsync(cancelacion);

    public Task<IReadOnlyList<CargaAsignacionResumen>> ConsultarAsync(
        byte? idCartera, CancellationToken cancelacion = default) =>
        repositorio.ConsultarAsync(idCartera is > 0 ? idCartera : null, cancelacion);

    public Task<ResultadoCargaAsignacion> CrearAsync(
        SolicitudCargaAsignacion solicitud, CancellationToken cancelacion = default)
    {
        var nombre = (solicitud.NombreArchivo ?? string.Empty).Trim();
        if (nombre.Length == 0)
            throw new ArgumentException("El archivo es obligatorio.", nameof(solicitud));

        var filas = (solicitud.Filas ?? [])
            .Where(f => !string.IsNullOrWhiteSpace(f))
            .Take(MaximoFilas)
            .Select(f => f.Trim())
            .ToList();

        var normalizada = solicitud with
        {
            NombreArchivo = nombre,
            RutaArchivo = string.IsNullOrWhiteSpace(solicitud.RutaArchivo) ? null : solicitud.RutaArchivo.Trim(),
            Filas = filas,
        };

        return repositorio.CrearAsync(normalizada, usuario.IdUsuario, usuario.Usuario, cancelacion);
    }
}
