using UnoContact.Crm.Application.Acceso;
using UnoContact.Crm.Application.Sesion;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace UnoContact.Crm.Server.Controllers;

public sealed record OpcionPermiso(string Clave, string Titulo, string Grupo, string Icono);

/// <summary>Catálogo de permisos (opciones de menú) y lo que le toca a cada puesto.</summary>
[ApiController]
[Route("api/permisos")]
[Authorize]
public sealed class PermisosController(IOptions<MapeoPerfiles> mapeo) : ControllerBase
{
    /// <summary>Opciones de menú que se pueden dar, agrupadas como en el menú ("inicio" siempre se tiene).</summary>
    [HttpGet("catalogo")]
    public ActionResult<IReadOnlyList<OpcionPermiso>> Catalogo() =>
        Ok(CatalogoMenu.Opciones
            .Where(o => o.Clave != ReglasPermisos.Inicio)
            .Select(o => new OpcionPermiso(o.Clave, o.Titulo, o.Grupo ?? o.Titulo, o.Icono))
            .ToList());

    /// <summary>Permisos que le tocan a un puesto (para marcar las casillas al elegirlo).</summary>
    [HttpGet("puesto/{idPuesto:int}")]
    public ActionResult<IReadOnlyList<string>> DelPuesto(short idPuesto) =>
        Ok(ReglasPermisos.Base(mapeo.Value.PerfilesDe(idPuesto), esRoot: false)
            .Where(c => c != ReglasPermisos.Inicio)
            .OrderBy(c => c)
            .ToList());
}
