using UnoContact.Crm.Application.Usuarios;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace UnoContact.Crm.Server.Controllers;

/// <summary>
/// Administración de usuarios para el Administrador: ver, desbloquear y forzar cambio
/// de contraseña. El alcance se limita a la cartera activa de la sesión (misma campaña).
/// </summary>
[ApiController]
[Route("api/usuarios")]
[Authorize(Policy = "Administrador")]
public sealed class UsuariosController(IServicioUsuarios servicio) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<UsuarioAdmin>>> Consultar(
        [FromQuery] bool soloBloqueados = false,
        CancellationToken cancelacion = default)
    {
        return Ok(await servicio.ConsultarAsync(soloBloqueados, cancelacion));
    }

    [HttpPost("{id:int}/desbloquear")]
    public async Task<IActionResult> Desbloquear(int id, CancellationToken cancelacion)
    {
        var actuo = await servicio.DesbloquearAsync(id, cancelacion);
        if (!actuo)
        {
            return Problem(
                statusCode: StatusCodes.Status403Forbidden,
                title: "El usuario no pertenece a tu campaña.");
        }

        return NoContent();
    }

    [HttpPost("{id:int}/forzar-cambio")]
    public async Task<IActionResult> ForzarCambio(int id, CancellationToken cancelacion)
    {
        var actuo = await servicio.ForzarCambioAsync(id, cancelacion);
        if (!actuo)
        {
            return Problem(
                statusCode: StatusCodes.Status403Forbidden,
                title: "El usuario no pertenece a tu campaña.");
        }

        return NoContent();
    }

    [HttpPost("{id:int}/bloquear")]
    public async Task<IActionResult> Bloquear(int id, CancellationToken cancelacion)
    {
        if (id == servicio.IdUsuarioActual)
        {
            return Problem(statusCode: StatusCodes.Status400BadRequest, title: "No puedes bloquear tu propio usuario.");
        }

        var actuo = await servicio.BloquearManualAsync(id, cancelacion);
        return actuo
            ? NoContent()
            : Problem(statusCode: StatusCodes.Status403Forbidden, title: "El usuario no pertenece a tu campaña.");
    }

    // La baja/reactivación (Activo) NO va aquí: pertenece a la pantalla de "Bajas de personal" (RH).
    // El servicio conserva CambiarActivoAsync y el SP seg.USP_ACTIVAR_USUARIO para reutilizarlos ahí.
}
