using System.ComponentModel.DataAnnotations;
using UnoContact.Crm.Application.Catalogos;

namespace UnoContact.Crm.Application.Carteras;

/// <summary>Personal que se puede asignar a una cartera (cart.USP_CONSULTA_PERSONAL).</summary>
public sealed record PersonalCartera(
    int IdEmpleado,
    string NombreCompleto,
    byte IdPuesto,
    string Puesto,
    byte IdDepartamento,
    string Departamento,
    byte? IdCartera,
    string? Cartera,
    bool Asignado,
    bool Operativo,
    byte IdAreaDep,
    byte IdSegmento,
    byte IdProducto,
    byte IdCampana);

public sealed record SolicitudAsignacionPersonal(
    IReadOnlyList<int> IdsEmpleados,
    byte IdCartera,
    byte? IdDepartamento,
    bool Operativo);

public sealed record ResultadoAsignacion(int Asignados, int Omitidos, string Mensaje);

public sealed record ResultadoRestauracion(int Restaurados, string Mensaje);

public sealed record OperativoResumen(
    int IdRegistro,
    int IdEmpleado,
    string NombreCompleto,
    byte IdAreaDep,
    string Area,
    byte IdCartera,
    string Cartera,
    byte IdSegmento,
    byte IdProducto,
    byte IdCampana,
    DateTime FechaRegistro);

public interface IRepositorioCarteras
{
    Task<CarteraDto?> ValidarAsync(int idUsuario, byte idCartera, CancellationToken cancelacion = default);

    Task<IReadOnlyList<PersonalCartera>> ConsultarPersonalAsync(
        byte idCartera, string? texto, CancellationToken cancelacion = default);

    Task<ResultadoAsignacion> AsignarAsync(
        SolicitudAsignacionPersonal solicitud, string usuario, CancellationToken cancelacion = default);

    Task<ResultadoRestauracion> RestaurarAsync(
        IReadOnlyList<int> idsEmpleados, string usuario, CancellationToken cancelacion = default);

    Task<IReadOnlyList<OperativoResumen>> ConsultarOperativoAsync(
        int? idEmpleado, byte? idCartera, CancellationToken cancelacion = default);
}

public interface IServicioCarteras
{
    Task<IReadOnlyList<CarteraDto>> ConsultarAsync(CancellationToken cancelacion = default);

    Task<CarteraDto?> ValidarAsync(byte idCartera, CancellationToken cancelacion = default);

    Task<IReadOnlyList<PersonalCartera>> ConsultarPersonalAsync(
        byte idCartera, string? texto, CancellationToken cancelacion = default);

    Task<ResultadoAsignacion> AsignarAsync(
        SolicitudAsignacionPersonal solicitud, CancellationToken cancelacion = default);

    Task<ResultadoRestauracion> RestaurarAsync(
        IReadOnlyList<int> idsEmpleados, CancellationToken cancelacion = default);

    Task<IReadOnlyList<OperativoResumen>> ConsultarOperativoAsync(
        int? idEmpleado, byte? idCartera, CancellationToken cancelacion = default);
}
