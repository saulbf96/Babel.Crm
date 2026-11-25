using UnoContact.Crm.Domain.Seguridad;

namespace UnoContact.Crm.Application.Sesion;

/// <summary>Opción del menú principal del CRM.</summary>
/// <param name="Grupo">Sección del menú legacy a la que pertenece (Gestión, Herramientas, etc.).</param>
public sealed record OpcionMenu(
    string Clave,
    string Titulo,
    string Icono,
    string Ruta,
    IReadOnlyList<Perfil> Perfiles,
    string? Grupo = null);

/// <summary>
/// Menú del CRM por perfil. Reemplaza la carga de menú por puesto de FRM_PRINCIPAL (escritorio).
/// Los grupos "Gestión" y "Herramientas" reproducen el MenuStrip de FRM_GESTION_CARTERA:
/// Gestión = 4 submenús, Herramientas = 7 submenús.
/// </summary>
public static class CatalogoMenu
{
    private static readonly IReadOnlyList<Perfil> Gestores =
        [Perfil.Asesor, Perfil.Supervisor, Perfil.Administrador];

    public static IReadOnlyList<OpcionMenu> Opciones { get; } =
    [
        new("inicio", "Inicio", "home", "/inicio", Gestores),

        // --- FRM_GESTION_CARTERA: menú "Gestión" (4 submenús) ---
        new("gestion-nueva", "Nueva Gestion", "support_agent", "/asesor", Gestores, "Gestión"),
        new("gestion-bloquear", "Bloquear", "lock", "/gestion/bloquear", Gestores, "Gestión"),
        new("gestion-cancelar", "Cancelar", "cancel", "/gestion/cancelar", Gestores, "Gestión"),
        new("gestion-agendar", "Agendar Llamada", "event", "/gestion/agendar-llamada", Gestores, "Gestión"),

        // --- FRM_GESTION_CARTERA: menú "Herramientas" (7 submenús) ---
        new("herramientas-buscar", "Buscar", "search", "/herramientas/buscar", Gestores, "Herramientas"),
        new("herramientas-notas", "Notas", "note", "/herramientas/notas", Gestores, "Herramientas"),
        new("herramientas-bloc", "Bloc de Notas", "description", "/herramientas/bloc-notas", Gestores, "Herramientas"),
        new("herramientas-calculadora", "Calculadora", "calculate", "/herramientas/calculadora", Gestores, "Herramientas"),
        new("herramientas-actualiza", "Actualiza Información", "update", "/herramientas/actualiza-informacion", Gestores, "Herramientas"),
        new("herramientas-expedientes", "Expedientes", "folder", "/herramientas/expedientes", Gestores, "Herramientas"),
        new("herramientas-softphone", "Softphone", "phone", "/herramientas/softphone", Gestores, "Herramientas"),

        new("supervision", "Supervisión", "monitoring", "/supervision", [Perfil.Supervisor]),

        // --- Área de Administración (las cinco pantallas del BABEL ADMINISTRATIVO) ---
        new("empleados", "Consulta de empleados", "badge", "/administracion/empleados", [Perfil.Administrador], "Administración"),
        new("alta-empleados", "Alta de empleados", "person_add", "/administracion/alta-empleados", [Perfil.Administrador], "Administración"),
        new("asignar-personal", "Asignar personal", "group_add", "/administracion/asignar-personal", [Perfil.Administrador], "Administración"),
        new("cambiar-cartera", "Cambia cartera", "swap_horiz", "/administracion/cambiar-cartera", [Perfil.Administrador], "Administración"),
        new("carga-asignaciones", "Carga de asignaciones", "upload_file", "/administracion/carga-asignaciones", [Perfil.Administrador], "Administración"),
    ];

    public static IReadOnlyList<OpcionMenu> ParaPerfiles(IEnumerable<Perfil> perfiles)
    {
        var conjunto = perfiles.ToHashSet();
        return Opciones.Where(o => o.Perfiles.Any(conjunto.Contains)).ToList();
    }
}
