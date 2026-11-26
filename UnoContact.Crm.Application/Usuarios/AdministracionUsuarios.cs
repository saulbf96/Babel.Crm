using UnoContact.Crm.Application.Abstracciones;

namespace UnoContact.Crm.Application.Usuarios;

/// <summary>Usuario del CRM visto por el Administrador de su misma campaña.</summary>
public sealed record UsuarioAdmin(
    int IdUsuario,
    string Usuario,
    string Empleado,
    string Puesto,
    string Cartera,
    bool Activo,
    bool Bloqueado,
    bool DebeCambiarContrasena,
    DateTime? UltimoAcceso);

/// <summary>Acceso a datos de administración de usuarios (alcance por cartera).</summary>
public interface IRepositorioUsuariosAdmin
{
    Task<IReadOnlyList<UsuarioAdmin>> ConsultarAsync(int idCartera, bool soloBloqueados, CancellationToken cancelacion);

    /// <summary>Desbloquea solo si el usuario pertenece a la cartera. Regresa true si actuó.</summary>
    Task<bool> DesbloquearAsync(int idUsuario, int idCartera, CancellationToken cancelacion);

    /// <summary>Marca cambio de contraseña pendiente si el usuario pertenece a la cartera. Regresa true si actuó.</summary>
    Task<bool> ForzarCambioAsync(int idUsuario, int idCartera, CancellationToken cancelacion);

    /// <summary>Activa o da de baja (lógica) al usuario, si pertenece a la cartera. Regresa true si actuó.</summary>
    Task<bool> CambiarActivoAsync(int idUsuario, int idCartera, bool activo, CancellationToken cancelacion);

    /// <summary>Bloqueo manual si el usuario pertenece a la cartera. Regresa true si actuó.</summary>
    Task<bool> BloquearManualAsync(int idUsuario, int idCartera, CancellationToken cancelacion);
}

/// <summary>
/// Administración de usuarios del CRM para el Administrador. El alcance se limita
/// SIEMPRE a la cartera activa de la sesión: un admin solo ve y actúa sobre usuarios
/// de su misma campaña.
/// </summary>
public interface IServicioUsuarios
{
    Task<IReadOnlyList<UsuarioAdmin>> ConsultarAsync(bool soloBloqueados, CancellationToken cancelacion);

    Task<bool> DesbloquearAsync(int idUsuario, CancellationToken cancelacion);

    Task<bool> ForzarCambioAsync(int idUsuario, CancellationToken cancelacion);

    Task<bool> BloquearManualAsync(int idUsuario, CancellationToken cancelacion);

    /// <summary>true = reactiva; false = baja lógica. No deja al admin desactivarse a sí mismo.</summary>
    Task<bool> CambiarActivoAsync(int idUsuario, bool activo, CancellationToken cancelacion);

    /// <summary>El usuario autenticado (para no permitir que se desactive a sí mismo).</summary>
    int IdUsuarioActual { get; }
}

public sealed class ServicioUsuarios(IRepositorioUsuariosAdmin repositorio, IUsuarioActual actual) : IServicioUsuarios
{
    public Task<IReadOnlyList<UsuarioAdmin>> ConsultarAsync(bool soloBloqueados, CancellationToken cancelacion) =>
        repositorio.ConsultarAsync(actual.IdCartera, soloBloqueados, cancelacion);

    public Task<bool> DesbloquearAsync(int idUsuario, CancellationToken cancelacion) =>
        repositorio.DesbloquearAsync(idUsuario, actual.IdCartera, cancelacion);

    public Task<bool> ForzarCambioAsync(int idUsuario, CancellationToken cancelacion) =>
        repositorio.ForzarCambioAsync(idUsuario, actual.IdCartera, cancelacion);

    public Task<bool> BloquearManualAsync(int idUsuario, CancellationToken cancelacion) =>
        repositorio.BloquearManualAsync(idUsuario, actual.IdCartera, cancelacion);

    public int IdUsuarioActual => actual.IdUsuario;

    public Task<bool> CambiarActivoAsync(int idUsuario, bool activo, CancellationToken cancelacion) =>
        repositorio.CambiarActivoAsync(idUsuario, actual.IdCartera, activo, cancelacion);
}
