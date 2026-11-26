using UnoContact.Crm.Domain.Seguridad;
using Microsoft.Extensions.Options;

namespace UnoContact.Crm.Application.Acceso;

public sealed record SolicitudAcceso(string Usuario, string Contrasena, string Ip, string Equipo);

public sealed record ResultadoAcceso(
    bool Exitoso,
    string? Mensaje,
    UsuarioCrm? Usuario = null,
    IReadOnlyCollection<Perfil>? Perfiles = null,
    MotivoCambioContrasena MotivoCambio = MotivoCambioContrasena.Ninguno)
{
    public bool DebeCambiarContrasena => MotivoCambio != MotivoCambioContrasena.Ninguno;

    public static ResultadoAcceso Rechazado(string mensaje) => new(false, mensaje);
}

public interface IServicioAcceso
{
    Task<ResultadoAcceso> IniciarSesionAsync(SolicitudAcceso solicitud, CancellationToken cancelacion = default);
}

/// <summary>
/// Inicio de sesión con usuario y contraseña de BABEL. Replica las reglas de FRM_ACCESO
/// (bloqueo al tercer intento fallido, usuario bloqueado, cambio de contraseña pendiente)
/// sin el acceso "fuera de línea" ni el registro de contraseñas en la bitácora.
/// </summary>
public sealed class ServicioAcceso(
    IRepositorioUsuarios repositorio,
    IControlIntentos intentos,
    IOptions<MapeoPerfiles> mapeo) : IServicioAcceso
{
    public const int IntentosPermitidos = 3;

    // Mensaje único para no revelar si el usuario existe.
    public const string MensajeInvalido = "Usuario y/o contraseña incorrectos.";

    public async Task<ResultadoAcceso> IniciarSesionAsync(SolicitudAcceso solicitud, CancellationToken cancelacion = default)
    {
        // BABEL convierte el usuario a mayúsculas mientras se escribe y hace Trim a ambos campos.
        var usuario = solicitud.Usuario?.Trim().ToUpperInvariant() ?? string.Empty;
        var contrasena = solicitud.Contrasena?.Trim() ?? string.Empty;
        if (usuario.Length == 0 || contrasena.Length == 0)
        {
            return ResultadoAcceso.Rechazado("Escribe tu usuario y contraseña.");
        }

        var encontrado = await repositorio.ValidarAsync(usuario, contrasena, cancelacion);
        if (encontrado is null)
        {
            var fallos = intentos.RegistrarFallo(usuario);
            if (fallos >= IntentosPermitidos)
            {
                await repositorio.BloquearAsync(usuario, solicitud.Ip, solicitud.Equipo, (byte)fallos, cancelacion);
                intentos.Reiniciar(usuario);
                return ResultadoAcceso.Rechazado("El usuario se bloqueó por intentos fallidos. Repórtalo al área de sistemas.");
            }

            return ResultadoAcceso.Rechazado(MensajeInvalido);
        }

        intentos.Reiniciar(usuario);

        if (encontrado.Bloqueado)
        {
            return ResultadoAcceso.Rechazado("El usuario se encuentra bloqueado. Repórtalo al área de sistemas.");
        }

        // BABEL no revisa la columna ACTIVO al entrar; aquí se exige. "Por confirmar con usuarios".
        if (!encontrado.Activo)
        {
            return ResultadoAcceso.Rechazado("El usuario no está activo. Repórtalo al área de sistemas.");
        }

        var perfiles = mapeo.Value.PerfilesDe(encontrado.IdPuesto);
        if (perfiles.Count == 0)
        {
            return ResultadoAcceso.Rechazado("Tu puesto no tiene acceso al CRM. Repórtalo al área de sistemas.");
        }

        // Cambio pendiente: forzado por un admin, o contraseña vencida (PoliticaContrasena.DiasVigencia).
        var motivo = await repositorio.EstadoContrasenaAsync(encontrado.IdUsuario, PoliticaContrasena.DiasVigencia, cancelacion);
        return new ResultadoAcceso(true, null, encontrado, perfiles, motivo);
    }
}
