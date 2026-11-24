using System.Data;
using Babel.Crm.Application.Abstracciones;
using Babel.Crm.Application.Acceso;
using Microsoft.Extensions.Options;

namespace Babel.Crm.Infrastructure.Identidad;

/// <summary>Opciones de seguridad que vienen de configuración segura (user-secrets / servidor).</summary>
public sealed class OpcionesSeguridad
{
    public const string Seccion = "Seguridad";

    /// <summary>
    /// Llave que los procedimientos de BABEL reciben en el parámetro @EMPATAR para validar contraseñas.
    /// NUNCA va en el código ni en appsettings.json: solo en user-secrets o en el servidor.
    /// </summary>
    public string LlaveBabel { get; set; } = string.Empty;
}

/// <summary>Usuarios de BABEL mediante sus procedimientos almacenados, siempre con parámetros.</summary>
public sealed class RepositorioUsuariosBabel(
    IEjecutorProcedimientos procedimientos,
    IOptions<OpcionesSeguridad> opciones) : IRepositorioUsuarios
{
    public async Task<UsuarioBabel?> ValidarAsync(string usuario, string contrasena, CancellationToken cancelacion)
    {
        var renglones = await procedimientos.ConsultarAsync(
            "CONFIGURACION_APP.DBO.CONSULTA_NEEM_EMPLEADO",
            [
                new ParametroSp("@EMPATAR", Llave(), DbType.AnsiString),
                new ParametroSp("@USUARIO", usuario, DbType.AnsiString),
                new ParametroSp("@PASSWORD", contrasena, DbType.AnsiString),
            ],
            r => new UsuarioBabel(
                Convert.ToInt32(r["ID EMPLEADO"]),
                Convert.ToString(r["USUARIO"]) ?? usuario,
                Convert.ToInt16(r["ID PUESTO"]),
                Convert.ToInt16(r["ID AREA DEPARTAMENTO"]),
                Convert.ToBoolean(r["BLOQUEADO"]),
                Convert.ToBoolean(r["ACTIVO"]),
                Convert.ToInt16(r["ID BASE DE DATOS"]),
                Convert.ToString(r["BASE DE DATOS"]) ?? string.Empty),
            cancelacion);

        // Igual que BABEL: el acceso es válido solo si regresa exactamente un renglón.
        return renglones.Count == 1 ? renglones[0] : null;
    }

    public async Task<bool> DebeCambiarContrasenaAsync(int idEmpleado, CancellationToken cancelacion)
    {
        var renglones = await procedimientos.ConsultarAsync(
            "CONFIGURACION_APP.DBO.CONSULTA_NECP_CAMBIO_PASSWORD",
            [new ParametroSp("@ID_EMPLEADO", (short)idEmpleado, DbType.Int16)],
            _ => true,
            cancelacion);
        return renglones.Count >= 1;
    }

    public Task BloquearAsync(string usuario, string ip, string equipo, byte intentos, CancellationToken cancelacion) =>
        procedimientos.EjecutarAsync(
            "LOGSSISTEMA.DBO.INSERTA_HIBP_LOG_BLOQUEOS_PERSONAL",
            [
                new ParametroSp("@USUARIO", usuario, DbType.AnsiString),
                new ParametroSp("@IP", ip, DbType.AnsiString),
                new ParametroSp("@HOST", equipo, DbType.AnsiString),
                new ParametroSp("@INTENTOS", intentos, DbType.Byte),
            ],
            cancelacion);

    private string Llave() =>
        string.IsNullOrEmpty(opciones.Value.LlaveBabel)
            ? throw new InvalidOperationException("Falta 'Seguridad:LlaveBabel'. Configúrala con user-secrets (ver README).")
            : opciones.Value.LlaveBabel;
}
