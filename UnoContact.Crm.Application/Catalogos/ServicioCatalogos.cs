using UnoContact.Crm.Application.Abstracciones;
using UnoContact.Crm.Application.Catalogos;

namespace UnoContact.Crm.Application.Catalogos;

/// <summary>Junta los catálogos en una sola llamada para las pantallas de Administración.</summary>
public sealed class ServicioCatalogos(
    IRepositorioCatalogos repositorio,
    IUsuarioActual usuario) : IServicioCatalogos
{
    public async Task<CatalogosDto> ConsultarAsync(CancellationToken cancelacion = default)
    {
        var carteras = await repositorio.ConsultarCarterasAsync(usuario.IdUsuario, cancelacion);
        var puestos = await repositorio.ConsultarPuestosAsync(cancelacion);
        var departamentos = await repositorio.ConsultarDepartamentosAsync(cancelacion);
        var sexos = await repositorio.ConsultarSexosAsync(cancelacion);
        var turnos = await repositorio.ConsultarTurnosAsync(cancelacion);

        return new CatalogosDto(carteras, puestos, departamentos, sexos, turnos);
    }
}
