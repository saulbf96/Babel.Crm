using UnoContact.Crm.Application.Abstracciones;

namespace UnoContact.Crm.Application.Rh;

/// <summary>Causa de baja (catálogo rh.CausaBaja = RHBABEL.CACB_CAUSA_BAJA).</summary>
public sealed record CausaBaja(byte IdCausaBaja, string Nombre);

/// <summary>Renglón de la pantalla "Bajas de personal".</summary>
public sealed record EmpleadoBaja(
    int IdEmpleado,
    string NombreCompleto,
    string? Usuario,
    string Puesto,
    DateOnly FechaIngreso,
    bool Activo,
    DateOnly? FechaBaja,
    string? CausaBaja,
    string? ComentarioBaja,
    string? UsuarioBaja,
    DateTime? FechaRegistroBaja,   // cuándo se capturó la baja en el sistema (con hora)
    int CuentasAsignadas);

/// <summary>A = activos, B = dados de baja, T = todos.</summary>
public enum EstatusBaja { Activos, Bajas, Todos }

public sealed record SolicitudBaja(byte IdCausaBaja, string? Comentario, DateOnly? FechaBaja);

public sealed record SolicitudReactivacion(string? Comentario);

/// <summary>Lo que pasó al dar de baja: el admin debe reasignar las cuentas que tenía.</summary>
public sealed record ResultadoBaja(int CuentasAsignadas, int UsuariosDesactivados);

public interface IRepositorioBajas
{
    Task<IReadOnlyList<CausaBaja>> CausasAsync(CancellationToken cancelacion);

    Task<IReadOnlyList<EmpleadoBaja>> ConsultarAsync(byte idCartera, string? nombre, EstatusBaja estatus, CancellationToken cancelacion);

    Task<ResultadoBaja> DarDeBajaAsync(
        int idEmpleado, byte idCartera, byte idCausaBaja, string comentario, DateOnly fechaBaja,
        int idUsuarioActual, string usuario, CancellationToken cancelacion);

    Task ReactivarAsync(int idEmpleado, byte idCartera, string comentario, string usuario, CancellationToken cancelacion);
}

public interface IServicioBajas
{
    Task<IReadOnlyList<CausaBaja>> CausasAsync(CancellationToken cancelacion = default);

    Task<IReadOnlyList<EmpleadoBaja>> ConsultarAsync(string? nombre, EstatusBaja estatus, CancellationToken cancelacion = default);

    Task<ResultadoBaja> DarDeBajaAsync(int idEmpleado, SolicitudBaja solicitud, CancellationToken cancelacion = default);

    Task ReactivarAsync(int idEmpleado, SolicitudReactivacion solicitud, CancellationToken cancelacion = default);
}

/// <summary>
/// Bajas de personal (reemplaza FRM_BAJAPERSONAL, que en BABEL estaba roto).
/// Baja LÓGICA: empleado, sus asignaciones y su usuario quedan inactivos; nada se borra.
/// Siempre dentro de la cartera activa de la sesión. Causa y comentario obligatorios
/// (en BABEL el comentario era opcional; aquí se exige para auditoría).
/// </summary>
public sealed class ServicioBajas(IRepositorioBajas repositorio, IUsuarioActual usuario) : IServicioBajas
{
    public const int ComentarioMinimo = 10;
    public const int ComentarioMaximo = 500;

    public Task<IReadOnlyList<CausaBaja>> CausasAsync(CancellationToken cancelacion = default) =>
        repositorio.CausasAsync(cancelacion);

    public Task<IReadOnlyList<EmpleadoBaja>> ConsultarAsync(string? nombre, EstatusBaja estatus, CancellationToken cancelacion = default) =>
        repositorio.ConsultarAsync(Cartera(), string.IsNullOrWhiteSpace(nombre) ? null : nombre.Trim(), estatus, cancelacion);

    public Task<ResultadoBaja> DarDeBajaAsync(int idEmpleado, SolicitudBaja solicitud, CancellationToken cancelacion = default)
    {
        if (solicitud.IdCausaBaja == 0)
            throw new ArgumentException("Selecciona la causa de la baja.");

        var comentario = ValidarComentario(solicitud.Comentario);
        // La baja es siempre con fecha de HOY: no se registran bajas con fechas pasadas ni futuras.
        // (Si la solicitud trae otra fecha, se ignora; la base también la fuerza a hoy.)
        var fecha = DateOnly.FromDateTime(DateTime.Today);

        return repositorio.DarDeBajaAsync(
            idEmpleado, Cartera(), solicitud.IdCausaBaja, comentario, fecha,
            usuario.IdUsuario, usuario.Usuario, cancelacion);
    }

    public Task ReactivarAsync(int idEmpleado, SolicitudReactivacion solicitud, CancellationToken cancelacion = default) =>
        repositorio.ReactivarAsync(idEmpleado, Cartera(), ValidarComentario(solicitud.Comentario), usuario.Usuario, cancelacion);

    private static string ValidarComentario(string? comentario)
    {
        var c = (comentario ?? string.Empty).Trim();
        if (c.Length < ComentarioMinimo)
            throw new ArgumentException($"Escribe un comentario de al menos {ComentarioMinimo} caracteres.");
        if (c.Length > ComentarioMaximo)
            throw new ArgumentException($"El comentario no puede pasar de {ComentarioMaximo} caracteres.");
        return c;
    }

    private byte Cartera() =>
        usuario.IdCartera is >= 1 and <= 255
            ? (byte)usuario.IdCartera
            : throw new InvalidOperationException("La sesión no tiene una cartera activa.");
}
