using UnoContact.Crm.Application.Abstracciones;

namespace UnoContact.Crm.Application.Sesion;

/// <summary>Datos de la sesión que necesita el frontend para armar el menú y las rutas.</summary>
public sealed record SesionDto(
    int IdEmpleado,
    string Usuario,
    int IdCartera,
    string Cartera,
    bool DebeCambiarContrasena,
    IReadOnlyList<string> Perfiles,
    IReadOnlyList<OpcionMenuDto> Menu,
    string? MotivoCambioContrasena = null,
    IReadOnlyList<string>? Permisos = null,
    bool EsRoot = false);

public sealed record OpcionMenuDto(
    string Clave, string Titulo, string Icono, string Ruta, string? Grupo = null);

public interface IServicioSesion
{
    SesionDto ObtenerSesion();
}

public sealed class ServicioSesion(IUsuarioActual usuario) : IServicioSesion
{
    public SesionDto ObtenerSesion()
    {
        // El menú sale de los permisos (puesto + ajustes); sin permisos en la cookie, del perfil.
        var permisos = usuario.Permisos;
        var opciones = permisos.Count > 0
            ? CatalogoMenu.Opciones.Where(o => permisos.Contains(o.Clave))
            : CatalogoMenu.ParaPerfiles(usuario.Perfiles);
        var menu = opciones
            .Select(o => new OpcionMenuDto(o.Clave, o.Titulo, o.Icono, o.Ruta, o.Grupo))
            .ToList();

        return new SesionDto(
            usuario.IdEmpleado,
            usuario.Usuario,
            usuario.IdCartera,
            usuario.Cartera,
            usuario.DebeCambiarContrasena,
            usuario.Perfiles.Order().Select(p => p.ToString()).ToList(),
            menu,
            usuario.MotivoCambioContrasena,
            menu.Select(m => m.Clave).ToList(),
            usuario.EsRoot);
    }
}
