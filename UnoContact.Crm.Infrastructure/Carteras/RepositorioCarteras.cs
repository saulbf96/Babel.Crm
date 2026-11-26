using System.Data;
using System.Text.Json;
using UnoContact.Crm.Application.Abstracciones;
using UnoContact.Crm.Application.Carteras;
using UnoContact.Crm.Application.Catalogos;

namespace UnoContact.Crm.Infrastructure.Carteras;

/// <summary>Acceso a carteras, personal y operativo en BABEL_UNIFICADA.</summary>
public sealed class RepositorioCarteras(IEjecutorProcedimientos ejecutor) : IRepositorioCarteras
{
    private const string Base = "BABEL_UNIFICADA";

    public async Task<CarteraDto?> ValidarAsync(int idUsuario, byte idCartera, CancellationToken cancelacion = default)
    {
        var filas = await ejecutor.ConsultarAsync(
            $"{Base}.cart.USP_VALIDA_CARTERA",
            [
                new ParametroSp("IdUsuario", idUsuario, DbType.Int32),
                new ParametroSp("IdCartera", idCartera, DbType.Byte),
            ],
            r => new CarteraDto(
                IdCartera: Convert.ToByte(r["IdCartera"]),
                Nombre: Convert.ToString(r["Nombre"]) ?? string.Empty,
                IdCliente: Convert.ToByte(r["IdCliente"]),
                Cliente: Convert.ToString(r["Cliente"]) ?? string.Empty,
                IdBaseLegacy: r["IdBaseLegacy"] is DBNull ? null : Convert.ToByte(r["IdBaseLegacy"]),
                IdDepartamento: r["IdDepartamento"] is DBNull ? null : Convert.ToByte(r["IdDepartamento"])),
            cancelacion);

        return filas.Count > 0 ? filas[0] : null;
    }

    public Task<IReadOnlyList<PersonalCartera>> ConsultarPersonalAsync(
        byte idCartera, string? texto, CancellationToken cancelacion = default) =>
        ejecutor.ConsultarAsync(
            $"{Base}.cart.USP_CONSULTA_PERSONAL",
            [
                new ParametroSp("IdCartera", idCartera, DbType.Byte),
                new ParametroSp("Texto", texto, DbType.AnsiString, 100),
            ],
            r => new PersonalCartera(
                IdEmpleado: Convert.ToInt32(r["IdEmpleado"]),
                NombreCompleto: Convert.ToString(r["NombreCompleto"]) ?? string.Empty,
                IdPuesto: Convert.ToByte(r["IdPuesto"]),
                Puesto: Convert.ToString(r["Puesto"]) ?? string.Empty,
                IdDepartamento: Convert.ToByte(r["IdDepartamento"]),
                Departamento: Convert.ToString(r["Departamento"]) ?? string.Empty,
                IdCartera: r["IdCartera"] is DBNull ? null : Convert.ToByte(r["IdCartera"]),
                Cartera: r["Cartera"] is DBNull ? null : Convert.ToString(r["Cartera"]),
                Asignado: Convert.ToBoolean(r["Asignado"]),
                Operativo: Convert.ToBoolean(r["Operativo"]),
                IdAreaDep: Convert.ToByte(r["IdAreaDep"]),
                IdSegmento: Convert.ToByte(r["IdSegmento"]),
                IdProducto: Convert.ToByte(r["IdProducto"]),
                IdCampana: Convert.ToByte(r["IdCampana"])),
            cancelacion);

    public async Task<ResultadoAsignacion> AsignarAsync(
        SolicitudAsignacionPersonal solicitud, string usuario, CancellationToken cancelacion = default)
    {
        var ids = string.Join(',', solicitud.IdsEmpleados);

        var filas = await ejecutor.ConsultarAsync(
            $"{Base}.cart.USP_ASIGNA_PERSONAL",
            [
                new ParametroSp("IdsEmpleados", ids, DbType.AnsiString, -1),
                new ParametroSp("IdCartera", solicitud.IdCartera, DbType.Byte),
                new ParametroSp("IdDepartamento", solicitud.IdDepartamento, DbType.Byte),
                new ParametroSp("Operativo", solicitud.Operativo, DbType.Boolean),
                new ParametroSp("Usuario", usuario, DbType.AnsiString, 50),
            ],
            r => new ResultadoAsignacion(
                Asignados: Convert.ToInt32(r["Asignados"]),
                Omitidos: Convert.ToInt32(r["Omitidos"]),
                Mensaje: Convert.ToString(r["Mensaje"]) ?? string.Empty),
            cancelacion);

        return filas.Count > 0
            ? filas[0]
            : throw new InvalidOperationException("La asignación no devolvió resultado.");
    }

    public async Task<ResultadoRestauracion> RestaurarAsync(
        IReadOnlyList<int> idsEmpleados, string usuario, CancellationToken cancelacion = default)
    {
        var ids = string.Join(',', idsEmpleados);

        var filas = await ejecutor.ConsultarAsync(
            $"{Base}.cart.USP_RESTAURA_PERSONAL",
            [
                new ParametroSp("IdsEmpleados", ids, DbType.AnsiString, -1),
                new ParametroSp("Usuario", usuario, DbType.AnsiString, 50),
            ],
            r => new ResultadoRestauracion(
                Restaurados: Convert.ToInt32(r["Restaurados"]),
                Mensaje: Convert.ToString(r["Mensaje"]) ?? string.Empty),
            cancelacion);

        return filas.Count > 0
            ? filas[0]
            : throw new InvalidOperationException("La restauración no devolvió resultado.");
    }

    public Task<IReadOnlyList<OperativoResumen>> ConsultarOperativoAsync(
        int? idEmpleado, byte? idCartera, CancellationToken cancelacion = default) =>
        ejecutor.ConsultarAsync(
            $"{Base}.cart.USP_CONSULTA_OPERATIVO",
            [
                new ParametroSp("IdEmpleado", idEmpleado, DbType.Int32),
                new ParametroSp("IdCartera", idCartera, DbType.Byte),
            ],
            r => new OperativoResumen(
                IdRegistro: Convert.ToInt32(r["IdRegistro"]),
                IdEmpleado: Convert.ToInt32(r["IdEmpleado"]),
                NombreCompleto: Convert.ToString(r["NombreCompleto"]) ?? string.Empty,
                IdAreaDep: Convert.ToByte(r["IdAreaDep"]),
                Area: Convert.ToString(r["Area"]) ?? string.Empty,
                IdCartera: Convert.ToByte(r["IdCartera"]),
                Cartera: Convert.ToString(r["Cartera"]) ?? string.Empty,
                IdSegmento: Convert.ToByte(r["IdSegmento"]),
                IdProducto: Convert.ToByte(r["IdProducto"]),
                IdCampana: Convert.ToByte(r["IdCampana"]),
                FechaRegistro: Convert.ToDateTime(r["FechaRegistro"])),
            cancelacion);
}
