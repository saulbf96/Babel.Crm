namespace Babel.Crm.Application.Rh;

/// <summary>Acceso a los empleados del CRM (base única BABEL_CRM, esquema rh).</summary>
public interface IRepositorioEmpleados
{
    Task<IReadOnlyList<EmpleadoResumen>> ConsultarAsync(FiltroEmpleados filtro, CancellationToken cancelacion = default);
}

/// <summary>Caso de uso de consulta de empleados.</summary>
public interface IServicioEmpleados
{
    Task<IReadOnlyList<EmpleadoResumen>> ConsultarAsync(FiltroEmpleados filtro, CancellationToken cancelacion = default);
}
