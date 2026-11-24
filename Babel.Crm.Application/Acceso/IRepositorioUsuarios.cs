namespace Babel.Crm.Application.Acceso;

/// <summary>
/// Empleado devuelto por CONFIGURACION_APP.DBO.CONSULTA_NEEM_EMPLEADO, el mismo procedimiento
/// que usa FRM_ACCESO en BABEL GESTION y BABEL ADMINISTRATIVO.
/// </summary>
public sealed record UsuarioBabel(
    int IdEmpleado,
    string Usuario,
    short IdPuesto,
    short IdArea,
    bool Bloqueado,
    bool Activo,
    short IdBaseDatos,
    string BaseDatos);

/// <summary>Procedimientos de usuarios de BABEL.</summary>
public interface IRepositorioUsuarios
{
    /// <summary>Valida usuario y contraseña. Regresa null si no coinciden.</summary>
    Task<UsuarioBabel?> ValidarAsync(string usuario, string contrasena, CancellationToken cancelacion);

    /// <summary>Indica si el empleado tiene pendiente el cambio de contraseña (CONSULTA_NECP_CAMBIO_PASSWORD).</summary>
    Task<bool> DebeCambiarContrasenaAsync(int idEmpleado, CancellationToken cancelacion);

    /// <summary>Bloquea al usuario por intentos fallidos (LOGSSISTEMA.DBO.INSERTA_HIBP_LOG_BLOQUEOS_PERSONAL).</summary>
    Task BloquearAsync(string usuario, string ip, string equipo, byte intentos, CancellationToken cancelacion);
}

/// <summary>Cuenta los intentos fallidos por usuario en el servidor (en BABEL se contaban en la PC).</summary>
public interface IControlIntentos
{
    int RegistrarFallo(string usuario);

    void Reiniciar(string usuario);
}
