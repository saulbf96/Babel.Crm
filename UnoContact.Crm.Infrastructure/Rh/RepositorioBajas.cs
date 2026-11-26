using System.Data;
using UnoContact.Crm.Application.Abstracciones;
using UnoContact.Crm.Application.Rh;

namespace UnoContact.Crm.Infrastructure.Rh;

/// <summary>Bajas de personal en BABEL_UNIFICADA (script 17_rh_bajas.sql).</summary>
public sealed class RepositorioBajas(IEjecutorProcedimientos ejecutor) : IRepositorioBajas
{
    private const string Base = "BABEL_UNIFICADA.rh.";

    public Task<IReadOnlyList<CausaBaja>> CausasAsync(CancellationToken cancelacion) =>
        ejecutor.ConsultarAsync(
            Base + "USP_CONSULTA_CAUSAS_BAJA",
            [],
            r => new CausaBaja(Convert.ToByte(r["IdCausaBaja"]), Convert.ToString(r["Nombre"]) ?? string.Empty),
            cancelacion);

    public Task<IReadOnlyList<EmpleadoBaja>> ConsultarAsync(byte idCartera, string? nombre, EstatusBaja estatus, CancellationToken cancelacion) =>
        ejecutor.ConsultarAsync(
            Base + "USP_CONSULTA_BAJAS",
            [
                new ParametroSp("@IdCartera", idCartera, DbType.Byte),
                new ParametroSp("@Nombre", nombre, DbType.AnsiString, 100),
                new ParametroSp("@Estatus", estatus switch
                {
                    EstatusBaja.Bajas => "B",
                    EstatusBaja.Todos => "T",
                    _ => "A",
                }, DbType.AnsiStringFixedLength, 1),
            ],
            r => new EmpleadoBaja(
                IdEmpleado: Convert.ToInt32(r["IdEmpleado"]),
                NombreCompleto: Convert.ToString(r["NombreCompleto"]) ?? string.Empty,
                Usuario: Texto(r["Usuario"]),
                Puesto: Convert.ToString(r["Puesto"]) ?? string.Empty,
                FechaIngreso: DateOnly.FromDateTime(Convert.ToDateTime(r["FechaIngreso"])),
                Activo: Convert.ToBoolean(r["Activo"]),
                FechaBaja: r["FechaBaja"] is DBNull ? null : DateOnly.FromDateTime(Convert.ToDateTime(r["FechaBaja"])),
                CausaBaja: Texto(r["CausaBaja"]),
                ComentarioBaja: Texto(r["ComentarioBaja"]),
                UsuarioBaja: Texto(r["UsuarioBaja"]),
                FechaRegistroBaja: r["FechaRegistroBaja"] is DBNull ? null : Convert.ToDateTime(r["FechaRegistroBaja"]),
                CuentasAsignadas: Convert.ToInt32(r["CuentasAsignadas"])),
            cancelacion);

    public async Task<ResultadoBaja> DarDeBajaAsync(
        int idEmpleado, byte idCartera, byte idCausaBaja, string comentario, DateOnly fechaBaja,
        int idUsuarioActual, string usuario, CancellationToken cancelacion)
    {
        var filas = await ejecutor.ConsultarAsync(
            Base + "USP_BAJA_EMPLEADO",
            [
                new ParametroSp("@IdEmpleado", idEmpleado, DbType.Int32),
                new ParametroSp("@IdCartera", idCartera, DbType.Byte),
                new ParametroSp("@IdCausaBaja", idCausaBaja, DbType.Byte),
                new ParametroSp("@Comentario", comentario, DbType.AnsiString, 500),
                new ParametroSp("@FechaBaja", fechaBaja.ToDateTime(TimeOnly.MinValue), DbType.Date),
                new ParametroSp("@IdUsuarioActual", idUsuarioActual, DbType.Int32),
                new ParametroSp("@Usuario", usuario, DbType.AnsiString, 50),
            ],
            r => new ResultadoBaja(Convert.ToInt32(r["CuentasAsignadas"]), Convert.ToInt32(r["UsuariosDesactivados"])),
            cancelacion);

        return filas.Count > 0 ? filas[0] : new ResultadoBaja(0, 0);
    }

    public Task ReactivarAsync(int idEmpleado, byte idCartera, string comentario, string usuario, CancellationToken cancelacion) =>
        ejecutor.EjecutarAsync(
            Base + "USP_REACTIVAR_EMPLEADO",
            [
                new ParametroSp("@IdEmpleado", idEmpleado, DbType.Int32),
                new ParametroSp("@IdCartera", idCartera, DbType.Byte),
                new ParametroSp("@Comentario", comentario, DbType.AnsiString, 500),
                new ParametroSp("@Usuario", usuario, DbType.AnsiString, 50),
            ],
            cancelacion);

    private static string? Texto(object valor) => valor is DBNull ? null : Convert.ToString(valor);
}
