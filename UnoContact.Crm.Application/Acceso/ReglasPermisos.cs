using UnoContact.Crm.Application.Sesion;
using UnoContact.Crm.Domain.Seguridad;

namespace UnoContact.Crm.Application.Acceso;

/// <summary>Ajuste de permiso de un usuario contra lo de su puesto.</summary>
public sealed record AjustePermiso(string Clave, bool Concedido);

/// <summary>
/// Permisos por opción de menú (26/11/2026). Reglas del usuario:
///  - Permisos efectivos = lo del puesto (perfil) + ajustes por usuario. ROOT parte de TODO.
///  - "inicio" siempre se tiene.
///  - Solo administradores (perfil Administrador) o ROOT dan permisos, y solo los que ellos tienen.
///  - Nadie cambia sus propios permisos (lo hace otro administrador); ROOT sí puede.
/// La clave de cada permiso es la de <see cref="CatalogoMenu"/>.
/// </summary>
public static class ReglasPermisos
{
    public const string Inicio = "inicio";

    /// <summary>Todas las claves de permiso que existen.</summary>
    public static IReadOnlySet<string> Todas { get; } =
        CatalogoMenu.Opciones.Select(o => o.Clave).ToHashSet(StringComparer.Ordinal);

    /// <summary>Lo que le toca por su puesto (o todo, si es ROOT).</summary>
    public static HashSet<string> Base(IEnumerable<Perfil> perfiles, bool esRoot) =>
        esRoot
            ? Todas.ToHashSet(StringComparer.Ordinal)
            : CatalogoMenu.ParaPerfiles(perfiles).Select(o => o.Clave).ToHashSet(StringComparer.Ordinal);

    /// <summary>Permisos efectivos = base + ajustes.</summary>
    public static IReadOnlySet<string> Efectivos(IEnumerable<Perfil> perfiles, bool esRoot, IEnumerable<AjustePermiso> ajustes)
    {
        var permisos = Base(perfiles, esRoot);
        foreach (var a in ajustes.Where(a => Todas.Contains(a.Clave)))
        {
            if (a.Concedido) permisos.Add(a.Clave);
            else permisos.Remove(a.Clave);
        }
        permisos.Add(Inicio);
        return permisos;
    }

    /// <summary>Ajustes a guardar para que, con la base del puesto, queden exactamente los deseados.</summary>
    public static IReadOnlyList<AjustePermiso> Ajustes(IReadOnlySet<string> baseDelPuesto, IEnumerable<string> deseados)
    {
        var quiero = deseados.Where(Todas.Contains).ToHashSet(StringComparer.Ordinal);
        quiero.Add(Inicio);
        return Todas
            .Where(c => c != Inicio && quiero.Contains(c) != baseDelPuesto.Contains(c))
            .OrderBy(c => c, StringComparer.Ordinal)
            .Select(c => new AjustePermiso(c, quiero.Contains(c)))
            .ToList();
    }

    /// <summary>Formato para la base: "clave:1,clave:0".</summary>
    public static string Serializar(IEnumerable<AjustePermiso> ajustes) =>
        string.Join(',', ajustes.Select(a => $"{a.Clave}:{(a.Concedido ? 1 : 0)}"));

    /// <summary>¿Puede este usuario dar o quitar permisos?</summary>
    public static bool PuedeAdministrar(IEnumerable<Perfil> perfilesActor, bool actorEsRoot) =>
        actorEsRoot || perfilesActor.Contains(Perfil.Administrador);

    /// <summary>
    /// Valida un cambio de permisos. Regresa null si es válido o el mensaje para el usuario.
    /// </summary>
    /// <param name="actual">Permisos efectivos actuales del usuario destino (vacío si es nuevo).</param>
    /// <param name="deseados">Permisos que quedarían.</param>
    public static string? ValidarCambio(
        IEnumerable<Perfil> perfilesActor, bool actorEsRoot, IReadOnlySet<string> permisosActor,
        int idUsuarioActor, int? idUsuarioDestino,
        IReadOnlySet<string> actual, IEnumerable<string> deseados)
    {
        if (!PuedeAdministrar(perfilesActor, actorEsRoot))
            return "Solo un administrador puede dar o quitar permisos.";

        if (idUsuarioDestino == idUsuarioActor && !actorEsRoot)
            return "No puedes cambiar tus propios permisos; pídelo a otro administrador.";

        var quiero = deseados.Where(Todas.Contains).ToHashSet(StringComparer.Ordinal);
        quiero.Add(Inicio);
        var cambiados = Todas.Where(c => quiero.Contains(c) != actual.Contains(c));
        if (!actorEsRoot)
        {
            var ajenos = cambiados.Where(c => !permisosActor.Contains(c)).ToList();
            if (ajenos.Count > 0)
            {
                var titulos = CatalogoMenu.Opciones.Where(o => ajenos.Contains(o.Clave)).Select(o => o.Titulo);
                return $"No puedes dar ni quitar permisos que tú no tienes: {string.Join(", ", titulos)}.";
            }
        }
        return null;
    }
}
