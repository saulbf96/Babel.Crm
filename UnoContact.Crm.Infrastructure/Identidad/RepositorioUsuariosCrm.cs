using System.Data;
using UnoContact.Crm.Application.Abstracciones;
using UnoContact.Crm.Application.Acceso;
using UnoContact.Crm.Infrastructure.Seguridad;

namespace UnoContact.Crm.Infrastructure.Identidad;

/// <summary>
/// Usuarios del CRM en la base única BABEL_CRM (esquema seg), con contraseñas propias PBKDF2.
/// Reemplaza el login de BABEL, cuyos procedimientos están cifrados y cuya llave ya no se tiene.
/// </summary>
public sealed class RepositorioUsuariosCrm(
    IEjecutorProcedimientos procedimientos,
    IHashContrasenas hash) : IRepositorioUsuarios
{
    private sealed record RenglonUsuario(
        string Usuario, string Hash, int IdEmpleado, short IdCliente, string Cliente,
        short IdPuesto, short IdDepartamento, bool Activo, bool Bloqueado);

    public async Task<UsuarioCrm?> ValidarAsync(string usuario, string contrasena, CancellationToken cancelacion)
    {
        var renglones = await procedimientos.ConsultarAsync(
            "BABEL_CRM.seg.USP_CONSULTA_USUARIO",
            [new ParametroSp("@Usuario", usuario, DbType.AnsiString, 50)],
            r => new RenglonUsuario(
                Convert.ToString(r["Usuario"]) ?? usuario,
                Convert.ToString(r["HashContrasena"]) ?? string.Empty,
                Convert.ToInt32(r["IdEmpleado"]),
                Convert.ToInt16(r["IdCliente"]),
                Convert.ToString(r["Cliente"]) ?? string.Empty,
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
            IdEmpleado: u.IdEmpleado,
            Usuario: u.Usuario,
            IdPuesto: u.IdPuesto,
            IdArea: u.IdDepartamento,
            Bloqueado: u.Bloqueado,
            Activo: u.Activo,
            IdBaseDatos: u.IdCliente,
            BaseDatos: u.Cliente);
    }

    public async Task<bool> DebeCambiarContrasenaAsync(int idEmpleado, CancellationToken cancelacion)
    {
        var renglones = await procedimientos.ConsultarAsync(
            "BABEL_CRM.seg.USP_DEBE_CAMBIAR",
            [new ParametroSp("@IdEmpleado", idEmpleado, DbType.Int32)],
            _ => true,
            cancelacion);
        return renglones.Count >= 1;
    }

    public Task BloquearAsync(string usuario, string ip, string equipo, byte intentos, CancellationToken cancelacion) =>
        procedimientos.EjecutarAsync(
            "BABEL_CRM.seg.USP_BLOQUEAR_USUARIO",
            [
                new ParametroSp("@Usuario", usuario, DbType.AnsiString, 50),
                new ParametroSp("@Ip", ip, DbType.AnsiString, 45),
                new ParametroSp("@Equipo", equipo, DbType.AnsiString, 100),
                new ParametroSp("@Intentos", intentos, DbType.Byte),
            ],
            cancelacion);
}
