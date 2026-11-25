using UnoContact.Crm.Domain.Seguridad;

namespace UnoContact.Crm.Application.Sesion;

/// <summary>Opción del menú principal del CRM.</summary>
public sealed record OpcionMenu(string Clave, string Titulo, string Icono, string Ruta, IReadOnlyList<Perfil> Perfiles);

/// <summary>
/// Menú del CRM por perfil. Reemplaza la carga de menú por puesto de FRM_PRINCIPAL (escritorio).
/// Cada área agrupa los módulos que se irán migrando; un usuario con varios perfiles ve la suma.
/// Qué perfiles ven cada área está "Por confirmar con usuarios".
/// </summary>
public static class CatalogoMenu
{
    public static IReadOnlyList<OpcionMenu> Opciones { get; } =
    [
        new("inicio", "Inicio", "home", "/inicio", [Perfil.Asesor, Perfil.Supervisor, Perfil.Administrador]),
        new("asesor", "Gestión de cartera", "support_agent", "/asesor", [Perfil.Asesor]),
        new("supervision", "Supervisión", "monitoring", "/supervision", [Perfil.Supervisor]),
        // Área de Administración (las cinco pantallas del BABEL ADMINISTRATIVO).
        new("empleados", "Consulta de empleados", "badge", "/administracion/empleados", [Perfil.Administrador]),
        new("alta-empleados", "Alta de empleados", "person_add", "/administracion/alta-empleados", [Perfil.Administrador]),
        new("asignar-personal", "Asignar personal", "group_add", "/administracion/asignar-personal", [Perfil.Administrador]),
        new("cambiar-cartera", "Cambia cartera", "swap_horiz", "/administracion/cambiar-cartera", [Perfil.Administrador]),
        new("carga-asignaciones", "Carga de asignaciones", "upload_file", "/administracion/carga-asignaciones", [Perfil.Administrador]),
    ];

    public static IReadOnlyList<OpcionMenu> ParaPerfiles(IEnumerable<Perfil> perfiles)
    {
        var conjunto = perfiles.ToHashSet();
        return Opciones.Where(o => o.Perfiles.Any(conjunto.Contains)).ToList();
    }
}
