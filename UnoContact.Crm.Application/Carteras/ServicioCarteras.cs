using UnoContact.Crm.Application.Abstracciones;
using UnoContact.Crm.Application.Catalogos;

namespace UnoContact.Crm.Application.Carteras;

/// <summary>
/// Cambio de cartera y asignación de personal. Replica el comportamiento del .exe:
/// un empleado solo tiene una cartera activa y el cambio se hace moviéndolo.
/// </summary>
public sealed class ServicioCarteras(
    IRepositorioCarteras repositorio,
    IRepositorioCatalogos catalogos,
    IUsuarioActual usuario) : IServicioCarteras
{
    public Task<IReadOnlyList<CarteraDto>> ConsultarAsync(CancellationToken cancelacion = default) =>
        catalogos.ConsultarCarterasAsync(usuario.IdUsuario, cancelacion);

    public Task<CarteraDto?> ValidarAsync(byte idCartera, CancellationToken cancelacion = default) =>
        idCartera == 0
            ? Task.FromResult<CarteraDto?>(null)
            : repositorio.ValidarAsync(usuario.IdUsuario, idCartera, cancelacion);

    public Task<IReadOnlyList<PersonalCartera>> ConsultarPersonalAsync(
        byte idCartera, string? texto, CancellationToken cancelacion = default)
    {
        if (idCartera == 0) throw new ArgumentException("Selecciona una cartera.", nameof(idCartera));
        var filtro = string.IsNullOrWhiteSpace(texto) ? null : texto.Trim();
        return repositorio.ConsultarPersonalAsync(idCartera, filtro, cancelacion);
    }

    public Task<ResultadoAsignacion> AsignarAsync(
        SolicitudAsignacionPersonal solicitud, CancellationToken cancelacion = default)
    {
        if (solicitud.IdCartera == 0)
            throw new ArgumentException("Selecciona la cartera destino.", nameof(solicitud));

        var ids = LimpiarIds(solicitud.IdsEmpleados);
        if (ids.Count == 0)
            throw new ArgumentException("Selecciona al menos un empleado.", nameof(solicitud));

        var normalizada = solicitud with
        {
            IdsEmpleados = ids,
            IdDepartamento = solicitud.IdDepartamento is > 0 ? solicitud.IdDepartamento : null,
        };

        return repositorio.AsignarAsync(normalizada, usuario.Usuario, cancelacion);
    }

    public Task<ResultadoRestauracion> RestaurarAsync(
        IReadOnlyList<int> idsEmpleados, CancellationToken cancelacion = default)
    {
        var ids = LimpiarIds(idsEmpleados);
        if (ids.Count == 0)
            throw new ArgumentException("Selecciona al menos un empleado para restaurar.", nameof(idsEmpleados));

        return repositorio.RestaurarAsync(ids, usuario.Usuario, cancelacion);
    }

    public Task<IReadOnlyList<OperativoResumen>> ConsultarOperativoAsync(
        int? idEmpleado, byte? idCartera, CancellationToken cancelacion = default) =>
        repositorio.ConsultarOperativoAsync(idEmpleado, idCartera, cancelacion);

    private static IReadOnlyList<int> LimpiarIds(IReadOnlyList<int>? ids) =>
        (ids ?? [])
            .Where(id => id > 0)
            .Distinct()
            .ToList();
}
