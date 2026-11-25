using System.Data;
using UnoContact.Crm.Application.Abstracciones;
using UnoContact.Crm.Application.Rh;

namespace UnoContact.Crm.Infrastructure.Rh;

/// <summary>
/// Lee empleados de la base única BABEL_UNIFICADA mediante el procedimiento parametrizado
/// rh.USP_CONSULTA_EMPLEADOS (nombre en 3 partes para no depender de la base por defecto de la conexión).
/// </summary>
public sealed class RepositorioEmpleados(IEjecutorProcedimientos ejecutor) : IRepositorioEmpleados
{
    private const string Procedimiento = "BABEL_UNIFICADA.rh.USP_CONSULTA_EMPLEADOS";

    public Task<IReadOnlyList<EmpleadoResumen>> ConsultarAsync(FiltroEmpleados filtro, CancellationToken cancelacion = default)
    {
        var parametros = new[]
        {
            new ParametroSp("IdCartera",   filtro.IdCartera,  DbType.Byte),
            new ParametroSp("Nombre",      filtro.Nombre,     DbType.String, 100),
            new ParametroSp("IdPuesto",    filtro.IdPuesto,   DbType.Byte),
            new ParametroSp("SoloActivos", filtro.SoloActivos, DbType.Boolean),
        };

        return ejecutor.ConsultarAsync(Procedimiento, parametros, Mapear, cancelacion);
    }

    public async Task<ResultadoAltaEmpleado> AltaAsync(
        SolicitudAltaEmpleado solicitud,
        byte idCartera,
        string usuario,
        CancellationToken cancelacion = default)
    {
        var parametros = new[]
        {
            new ParametroSp("IdCartera", idCartera, DbType.Byte),
            new ParametroSp("IdPuesto",  solicitud.IdPuesto,  DbType.Byte),
            new ParametroSp("IdSexo",    solicitud.IdSexo,    DbType.Byte),
            new ParametroSp("IdTurno",   solicitud.IdTurno,   DbType.Byte),
            new ParametroSp("Nombre",    solicitud.Nombre,    DbType.AnsiString, 100),
            new ParametroSp("Paterno",   solicitud.Paterno,   DbType.AnsiString, 100),
            new ParametroSp("Materno",   solicitud.Materno,   DbType.AnsiString, 100),
            new ParametroSp("Usuario",   usuario,             DbType.AnsiString, 50),
        };

        var filas = await ejecutor.ConsultarAsync(
            "BABEL_UNIFICADA.rh.USP_ALTA_EMPLEADO",
            parametros,
            r => new ResultadoAltaEmpleado(
                Convert.ToInt32(r["IdEmpleado"]),
                Convert.ToString(r["Mensaje"]) ?? string.Empty),
            cancelacion);

        return filas.Count > 0
            ? filas[0]
            : throw new InvalidOperationException("El alta de empleado no devolvió resultado.");
    }

    private static EmpleadoResumen Mapear(IDataRecord r) => new(
        IdEmpleado: r.GetInt32(r.GetOrdinal("IdEmpleado")),
        NombreCompleto: r.GetString(r.GetOrdinal("NombreCompleto")),
        Usuario: LeerTextoNulo(r, "Usuario"),
        IdPuesto: r.GetByte(r.GetOrdinal("IdPuesto")),
        Puesto: r.GetString(r.GetOrdinal("Puesto")),
        IdDepartamento: r.GetByte(r.GetOrdinal("IdDepartamento")),
        Departamento: r.GetString(r.GetOrdinal("Departamento")),
        IdCartera: LeerByteNulo(r, "IdCartera"),
        Cartera: LeerTextoNulo(r, "Cartera"),
        IdSexo: r.GetByte(r.GetOrdinal("IdSexo")),
        Sexo: r.GetString(r.GetOrdinal("Sexo")),
        IdTurno: r.GetByte(r.GetOrdinal("IdTurno")),
        Turno: r.GetString(r.GetOrdinal("Turno")),
        FechaNacimiento: LeerFechaNulo(r, "FechaNacimiento"),
        FechaIngreso: DateOnly.FromDateTime(r.GetDateTime(r.GetOrdinal("FechaIngreso"))),
        Rfc: LeerTextoNulo(r, "Rfc"),
        Curp: LeerTextoNulo(r, "Curp"),
        Nss: LeerLongNulo(r, "Nss"),
        Email: LeerTextoNulo(r, "Email"),
        Activo: r.GetBoolean(r.GetOrdinal("Activo")),
        FechaRegistro: r.GetDateTime(r.GetOrdinal("FechaRegistro")));

    private static string? LeerTextoNulo(IDataRecord r, string columna)
    {
        var i = r.GetOrdinal(columna);
        return r.IsDBNull(i) ? null : r.GetString(i);
    }

    private static byte? LeerByteNulo(IDataRecord r, string columna)
    {
        var i = r.GetOrdinal(columna);
        return r.IsDBNull(i) ? null : r.GetByte(i);
    }

    private static long? LeerLongNulo(IDataRecord r, string columna)
    {
        var i = r.GetOrdinal(columna);
        return r.IsDBNull(i) ? null : r.GetInt64(i);
    }

    private static DateOnly? LeerFechaNulo(IDataRecord r, string columna)
    {
        var i = r.GetOrdinal(columna);
        return r.IsDBNull(i) ? null : DateOnly.FromDateTime(r.GetDateTime(i));
    }
}
