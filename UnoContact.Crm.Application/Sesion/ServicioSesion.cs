using UnoContact.Crm.Application.Abstracciones;

namespace UnoContact.Crm.Application.Sesion;

/// <summary>Datos de la sesión que necesita el frontend para armar el menú y las rutas.</summary>
public sealed record SesionDto(
    int IdEmpleado,
    string Usuario,
    int IdCartera,
    string Cartera,
    IReadOnlyList<string> Perfiles,
    IReadOnlyList<OpcionMenuDto> Menu);

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
        var menu = CatalogoMenu.ParaPerfiles(usuario.Perfiles)
            .Select(o => new OpcionMenuDto(o.Clave, o.Titulo, o.Icono, o.Ruta, o.Grupo))
            .ToList();

        return new SesionDto(
            usuario.IdEmpleado,
            usuario.Usuario,
            usuario.IdCartera,
            usuario.Cartera,
            usuario.Perfiles.Order().Select(p => p.ToString()).ToList(),
            menu);
    }
}
