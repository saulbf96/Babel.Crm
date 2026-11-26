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

/// <summary>Por qué el login exige cambiar la contraseña.</summary>
public enum MotivoCambioContrasena
{
    Ninguno,
    /// <summary>Lo pidió un administrador ("Forzar cambio") o es usuario nuevo.</summary>
    Forzado,
    /// <summary>Pasaron <see cref="PoliticaContrasena.DiasVigencia"/> días desde el último cambio.</summary>
    Vencida,
}

/// <summary>Resultado de comparar una contraseña nueva contra la actual y el historial.</summary>
public enum ReusoContrasena
{
    Ninguno,
    Actual,
    Anterior,
}

/// <summary>Procedimientos de usuarios del CRM.</summary>
public interface IRepositorioUsuarios
{
    /// <summary>Valida usuario y contraseña. Regresa null si no coinciden.</summary>
    Task<UsuarioCrm?> ValidarAsync(string usuario, string contrasena, CancellationToken cancelacion);

    /// <summary>Indica si el usuario debe cambiar su contraseña al entrar y por qué (forzado o vencida).</summary>
    Task<MotivoCambioContrasena> EstadoContrasenaAsync(int idUsuario, int diasVigencia, CancellationToken cancelacion);

    /// <summary>Revisa si la contraseña coincide con la actual o con alguna de las últimas <paramref name="recordadas"/>.</summary>
    Task<ReusoContrasena> RevisarReusoAsync(int idUsuario, string contrasena, int recordadas, CancellationToken cancelacion);

    /// <summary>Bloquea al usuario por intentos fallidos.</summary>
    Task BloquearAsync(string usuario, string ip, string equipo, byte intentos, CancellationToken cancelacion);

    /// <summary>Guarda la nueva contraseña (la cifra como hash) y baja la bandera de cambio pendiente.</summary>
    Task CambiarContrasenaAsync(int idUsuario, string contrasenaNueva, CancellationToken cancelacion);
}

/// <summary>Cuenta los intentos fallidos por usuario en el servidor.</summary>
public interface IControlIntentos
{
    int RegistrarFallo(string usuario);

    void Reiniciar(string usuario);
}
