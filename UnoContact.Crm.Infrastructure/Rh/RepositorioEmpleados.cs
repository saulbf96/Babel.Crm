using System.Data;
using UnoContact.Crm.Application.Abstracciones;
using UnoContact.Crm.Application.Rh;

namespace UnoContact.Crm.Infrastructure.Rh;

/// <summary>
/// Lee empleados de la base única BABEL_CRM mediante el procedimiento parametrizado
/// rh.USP_CONSULTA_EMPLEADOS (nombre en 3 partes para no depender de la base por defecto de la conexión).
/// </summary>
public sealed class RepositorioEmpleados(IEjecutorProcedimientos ejecutor) : IRepositorioEmpleados
{
    private const string Procedimiento = "BABEL_CRM.rh.USP_CONSULTA_EMPLEADOS";

    public Task<IReadOnlyList<EmpleadoResumen>> ConsultarAsync(FiltroEmpleados filtro, CancellationToken cancelacion = default)
    {
        var parametros = new[]
        {
            new ParametroSp("IdCliente",   filtro.IdCliente,  DbType.Int32),
            new ParametroSp("Nombre",      filtro.Nombre,     DbType.String, 100),
            new ParametroSp("IdPuesto",    filtro.IdPuesto,   DbType.Byte),
            new ParametroSp("SoloActivos", filtro.SoloActivos, DbType.Boolean),
        };

        return ejecutor.ConsultarAsync(Procedimiento, parametros, Mapear, cancelacion);
    }

    private static EmpleadoResumen Mapear(IDataRecord r) => new(
        IdEmpleado: r.GetInt32(r.GetOrdinal("IdEmpleado")),
        IdCliente: r.GetInt32(r.GetOrdinal("IdCliente")),
        Cliente: r.GetString(r.GetOrdinal("Cliente")),
        NombreCompleto: r.GetString(r.GetOrdinal("NombreCompleto")),
        IdPuesto: r.GetByte(r.GetOrdinal("IdPuesto")),
        Puesto: r.GetString(r.GetOrdinal("Puesto")),
        IdDepartamento: r.GetByte(r.GetOrdinal("IdDepartamento")),
        Departamento: r.GetString(r.GetOrdinal("Departamento")),
        Rfc: LeerTextoNulo(r, "Rfc"),
        Email: LeerTextoNulo(r, "Email"),
        FechaIngreso: DateOnly.FromDateTime(r.GetDateTime(r.GetOrdinal("FechaIngreso"))),
        Activo: r.GetBoolean(r.GetOrdinal("Activo")));

    private static string? LeerTextoNulo(IDataRecord r, string columna)
    {
        var i = r.GetOrdinal(columna);
        return r.IsDBNull(i) ? null : r.GetString(i);
    }
}
