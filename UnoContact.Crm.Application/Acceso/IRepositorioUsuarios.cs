namespace UnoContact.Crm.Application.Acceso;

/// <summary>
/// Empleado devuelto por BABEL_UNIFICADA.seg.USP_CONSULTA_USUARIO, el login propio
/// del CRM. La cartera inicial se toma de la asignacion activa del empleado.
/// </summary>
public sealed record UsuarioCrm(
    int IdUsuario,
    int IdEmpleado,
    string Usuario,
    short IdPuesto,
    short IdArea,
    bool Bloqueado,
    bool Activo,
    short IdCartera,
    string Cartera);

/// <summary>Procedimientos de usuarios del CRM.</summary>
public interface IRepositorioUsuarios
{
    /// <summary>Valida usuario y contraseña. Regresa null si no coinciden.</summary>
    Task<UsuarioCrm?> ValidarAsync(string usuario, string contrasena, CancellationToken cancelacion);

    /// <summary>Indica si el empleado tiene pendiente el cambio de contraseña.</summary>
    Task<bool> DebeCambiarContrasenaAsync(int idEmpleado, CancellationToken cancelacion);

    /// <summary>Bloquea al usuario por intentos fallidos.</summary>
    Task BloquearAsync(string usuario, string ip, string equipo, byte intentos, CancellationToken cancelacion);
}

/// <summary>Cuenta los intentos fallidos por usuario en el servidor.</summary>
public interface IControlIntentos
{
    int RegistrarFallo(string usuario);

    void Reiniciar(string usuario);
}
