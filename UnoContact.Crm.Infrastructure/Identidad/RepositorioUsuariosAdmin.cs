using System.Data;
using UnoContact.Crm.Application.Abstracciones;
using UnoContact.Crm.Application.Usuarios;

namespace UnoContact.Crm.Infrastructure.Identidad;

/// <summary>
/// Administración de usuarios (esquema seg de BABEL_UNIFICADA). Los SP validan el
/// alcance por cartera, así que un admin solo actúa sobre usuarios de su campaña.
/// </summary>
public sealed class RepositorioUsuariosAdmin(
    IEjecutorProcedimientos procedimientos,
    Seguridad.IHashContrasenas hash) : IRepositorioUsuariosAdmin
{
    private const string BaseDatos = "BABEL_UNIFICADA";

    public Task<IReadOnlyList<UsuarioAdmin>> ConsultarAsync(int idCartera, bool soloBloqueados, CancellationToken cancelacion) =>
        procedimientos.ConsultarAsync(
            $"{BaseDatos}.seg.USP_CONSULTA_USUARIOS",
            [
                new ParametroSp("@IdCartera", idCartera, DbType.Int32),
                new ParametroSp("@SoloBloqueados", soloBloqueados, DbType.Boolean),
            ],
            r => new UsuarioAdmin(
                Convert.ToInt32(r["IdUsuario"]),
                Convert.ToString(r["Usuario"]) ?? string.Empty,
                Convert.ToString(r["Empleado"]) ?? string.Empty,
                Convert.ToString(r["Puesto"]) ?? string.Empty,
                Convert.ToString(r["Cartera"]) ?? string.Empty,
                Convert.ToBoolean(r["Activo"]),
                Convert.ToBoolean(r["Bloqueado"]),
                Convert.ToBoolean(r["DebeCambiarContrasena"]),
                r["UltimoAcceso"] is DBNull ? null : Convert.ToDateTime(r["UltimoAcceso"])),
            cancelacion);

    public async Task<bool> DesbloquearAsync(int idUsuario, int idCartera, CancellationToken cancelacion) =>
        await EjecutarConAlcanceAsync("USP_DESBLOQUEAR_USUARIO", idUsuario, idCartera, cancelacion);

    public async Task<bool> ForzarCambioAsync(int idUsuario, int idCartera, CancellationToken cancelacion) =>
        await EjecutarConAlcanceAsync("USP_FORZAR_CAMBIO", idUsuario, idCartera, cancelacion);

    public async Task<bool> BloquearManualAsync(int idUsuario, int idCartera, CancellationToken cancelacion) =>
        await EjecutarConAlcanceAsync("USP_BLOQUEAR_MANUAL", idUsuario, idCartera, cancelacion);

    public async Task<bool> RestablecerContrasenaAsync(int idUsuario, int idCartera, string contrasenaTemporal, string usuario, CancellationToken cancelacion)
    {
        var filas = await procedimientos.ConsultarAsync(
            $"{BaseDatos}.seg.USP_RESTABLECER_CONTRASENA",
            [
                new ParametroSp("@IdUsuario", idUsuario, DbType.Int32),
                new ParametroSp("@IdCartera", idCartera, DbType.Int32),
                new ParametroSp("@HashContrasena", hash.Hashear(contrasenaTemporal), DbType.AnsiString, 200),
                new ParametroSp("@Usuario", usuario, DbType.AnsiString, 50),
            ],
            r => Convert.ToInt32(r["Afectados"]),
            cancelacion);
        return filas.Count > 0 && filas[0] > 0;
    }

    public async Task<bool> CambiarActivoAsync(int idUsuario, int idCartera, bool activo, CancellationToken cancelacion)
    {
        var filas = await procedimientos.ConsultarAsync(
            $"{BaseDatos}.seg.USP_ACTIVAR_USUARIO",
            [
                new ParametroSp("@IdUsuario", idUsuario, DbType.Int32),
                new ParametroSp("@IdCartera", idCartera, DbType.Int32),
                new ParametroSp("@Activo", activo, DbType.Boolean),
            ],
            r => Convert.ToInt32(r["Afectados"]),
            cancelacion);

        return filas.Count > 0 && filas[0] > 0;
    }

    private async Task<bool> EjecutarConAlcanceAsync(string procedimiento, int idUsuario, int idCartera, CancellationToken cancelacion)
    {
        var filas = await procedimientos.ConsultarAsync(
            $"{BaseDatos}.seg.{procedimiento}",
            [
                new ParametroSp("@IdUsuario", idUsuario, DbType.Int32),
                new ParametroSp("@IdCartera", idCartera, DbType.Int32),
            ],
            r => Convert.ToInt32(r["Afectados"]),
            cancelacion);

        return filas.Count > 0 && filas[0] > 0;
    }
}
