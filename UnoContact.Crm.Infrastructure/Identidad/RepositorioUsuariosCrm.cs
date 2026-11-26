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
        short IdPuesto, short IdDepartamento, bool Activo, bool Bloqueado,
        bool AplicaHorario, TimeOnly? HoraEntrada, TimeOnly? HoraSalida, bool EsRoot);

    private static TimeOnly? Hora(object valor) => valor is DBNull ? null : TimeOnly.FromTimeSpan((TimeSpan)valor);

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
                Convert.ToBoolean(r["Bloqueado"]),
                Convert.ToBoolean(r["AplicaHorario"]),
                Hora(r["HoraEntrada"]),
                Hora(r["HoraSalida"]),
                Convert.ToBoolean(r["EsRoot"])),
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
            Cartera: u.Cartera,
            AplicaHorario: u.AplicaHorario,
            HoraEntrada: u.HoraEntrada,
            HoraSalida: u.HoraSalida,
            EsRoot: u.EsRoot);
    }

    public async Task<MotivoCambioContrasena> EstadoContrasenaAsync(int idUsuario, int diasVigencia, CancellationToken cancelacion)
    {
        var renglones = await procedimientos.ConsultarAsync(
            $"{BaseDatos}.seg.USP_ESTADO_CONTRASENA",
            [
                new ParametroSp("@IdUsuario", idUsuario, DbType.Int32),
                new ParametroSp("@DiasVigencia", diasVigencia, DbType.Int32),
            ],
            r => Convert.ToString(r["Motivo"]),
            cancelacion);

        return renglones.FirstOrDefault() switch
        {
            null => MotivoCambioContrasena.Ninguno,
            "VENCIDA" => MotivoCambioContrasena.Vencida,
            _ => MotivoCambioContrasena.Forzado,
        };
    }

    public async Task<ReusoContrasena> RevisarReusoAsync(int idUsuario, string contrasena, int recordadas, CancellationToken cancelacion)
    {
        var hashes = await procedimientos.ConsultarAsync(
            $"{BaseDatos}.seg.USP_CONSULTA_HASHES_RECIENTES",
            [
                new ParametroSp("@IdUsuario", idUsuario, DbType.Int32),
                new ParametroSp("@Recordadas", recordadas, DbType.Int32),
            ],
            r => (EsActual: Convert.ToBoolean(r["EsActual"]), Hash: Convert.ToString(r["HashContrasena"]) ?? string.Empty),
            cancelacion);

        // Cada hash tiene su propia sal: hay que verificar uno por uno (no se puede comparar en SQL).
        foreach (var (esActual, h) in hashes.OrderByDescending(x => x.EsActual))
        {
            if (hash.Verificar(h, contrasena))
                return esActual ? ReusoContrasena.Actual : ReusoContrasena.Anterior;
        }

        return ReusoContrasena.Ninguno;
    }

    public Task<IReadOnlyList<AjustePermiso>> PermisosAsync(int idUsuario, CancellationToken cancelacion) =>
        procedimientos.ConsultarAsync(
            $"{BaseDatos}.seg.USP_CONSULTA_PERMISOS",
            [new ParametroSp("@IdUsuario", idUsuario, DbType.Int32)],
            r => new AjustePermiso(Convert.ToString(r["Clave"]) ?? string.Empty, Convert.ToBoolean(r["Concedido"])),
            cancelacion);

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

    public Task CambiarContrasenaAsync(int idUsuario, string contrasenaNueva, CancellationToken cancelacion) =>
        procedimientos.EjecutarAsync(
            $"{BaseDatos}.seg.USP_CAMBIAR_CONTRASENA",
            [
                new ParametroSp("@IdUsuario", idUsuario, DbType.Int32),
                new ParametroSp("@HashContrasena", hash.Hashear(contrasenaNueva), DbType.AnsiString, 200),
            ],
            cancelacion);
}
