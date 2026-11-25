using UnoContact.Crm.Application.Catalogos;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace UnoContact.Crm.Server.Controllers;

/// <summary>Catálogos para los combos de las pantallas de Administración.</summary>
[ApiController]
[Route("api/catalogos")]
[Authorize(Policy = "Administrador")]
public sealed class CatalogosController(IServicioCatalogos servicio) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<CatalogosDto>> Consultar(CancellationToken cancelacion)
    {
        var catalogos = await servicio.ConsultarAsync(cancelacion);
        return Ok(catalogos);
    }
}
