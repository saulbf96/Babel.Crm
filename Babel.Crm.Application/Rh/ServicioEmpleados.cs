namespace Babel.Crm.Application.Rh;

/// <summary>
/// Consulta de empleados. Normaliza el filtro antes de ir al repositorio.
/// Aquí se agregará, cuando toque, la restricción por cliente según el usuario.
/// </summary>
public sealed class ServicioEmpleados(IRepositorioEmpleados repositorio) : IServicioEmpleados
{
    public Task<IReadOnlyList<EmpleadoResumen>> ConsultarAsync(FiltroEmpleados filtro, CancellationToken cancelacion = default)
    {
        var nombre = string.IsNullOrWhiteSpace(filtro.Nombre) ? null : filtro.Nombre.Trim();
        var normalizado = filtro with { Nombre = nombre };
        return repositorio.ConsultarAsync(normalizado, cancelacion);
    }
}
