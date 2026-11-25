using System.Data;
using UnoContact.Crm.Application.Abstracciones;
using UnoContact.Crm.Application.Acceso;
using UnoContact.Crm.Infrastructure.Seguridad;

namespace UnoContact.Crm.Infrastructure.Identidad;

/// <summary>
/// Usuarios del CRM en la base única BABEL_UNIFICADA (esquema seg), con contraseñas
/// propias PBKDF2. Reemplaza el login de BABEL, cuyos procedimientos están cifrados
/// y devolvían la contraseña en claro.
/// </summary>
public sealed class RepositorioUsuariosCrm(
    IEjecutorProcedimientos procedimientos,
    IHashContrasenas hash) : IRepositorioUsuarios
{
    private const string BaseDatos = "BABEL_UNIFICADA";

    private sealed record RenglonUsuario(
        int IdUsuario, string Usuario, string Hash, int IdEmpleado, short IdCartera, string Cartera,
        short IdPuesto, short IdDepartamento, bool Activo, bool Bloqueado);

    public async Task<UsuarioCrm?> ValidarAsync(string usuario, string contrasena, CancellationToken cancelacion)
    {
        var renglones = await procedimientos.ConsultarAsync(
            $"{BaseDatos}.seg.USP_CONSULTA_USUARIO",
            [new ParametroSp("@Usuario", usuario, DbType.AnsiString, 50)],
            r => new RenglonUsuario(
                Convert.ToInt32(r["IdUsuario"]),
                Convert.ToString(r["Usuario"]) ?? usuario,
                Convert.ToString(r["HashContrasena"]) ?? string.Empty,
                Convert.ToInt32(r["IdEmpleado"]),
                r["IdCartera"] is DBNull ? (short)0 : Convert.ToInt16(r["IdCartera"]),
                r["Cartera"] is DBNull ? string.Empty : Convert.ToString(r["Cartera"]) ?? string.Empty,
                Convert.ToInt16(r["IdPuesto"]),
                Convert.ToInt16(r["IdDepartamento"]),
                Convert.ToBoolean(r["Activo"]),
                Convert.ToBoolean(r["Bloqueado"])),
            cancelacion);

        if (renglones.Count != 1) return null;

        var u = renglones[0];
        // La contraseña se verifica en el backend; el hash nunca sale del servidor.
        if (!hash.Verificar(u.Hash, contrasena)) return null;

        return new UsuarioCrm(
            IdUsuario: u.IdUsuario,
            IdEmpleado: u.IdEmpleado,
            Usuario: u.Usuario,
            IdPuesto: u.IdPuesto,
            IdArea: u.IdDepartamento,
            Bloqueado: u.Bloqueado,
            Activo: u.Activo,
            IdCartera: u.IdCartera,
            Cartera: u.Cartera);
    }

    public async Task<bool> DebeCambiarContrasenaAsync(int idEmpleado, CancellationToken cancelacion)
    {
        var renglones = await procedimientos.ConsultarAsync(
            $"{BaseDatos}.seg.USP_DEBE_CAMBIAR",
            [new ParametroSp("@IdEmpleado", idEmpleado, DbType.Int32)],
            _ => true,
            cancelacion);
        return renglones.Count >= 1;
    }

    public Task BloquearAsync(string usuario, string ip, string equipo, byte intentos, CancellationToken cancelacion) =>
        procedimientos.EjecutarAsync(
            $"{BaseDatos}.seg.USP_BLOQUEAR_USUARIO",
            [
                new ParametroSp("@Usuario", usuario, DbType.AnsiString, 50),
                new ParametroSp("@Ip", ip, DbType.AnsiString, 45),
                new ParametroSp("@Equipo", equipo, DbType.AnsiString, 100),
                new ParametroSp("@Intentos", intentos, DbType.Byte),
            ],
            cancelacion);
}
