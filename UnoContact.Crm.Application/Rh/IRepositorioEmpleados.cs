namespace UnoContact.Crm.Application.Rh;

/// <summary>Acceso a los empleados del CRM (base única BABEL_UNIFICADA, esquema rh).</summary>
public interface IRepositorioEmpleados
{
    Task<IReadOnlyList<EmpleadoResumen>> ConsultarAsync(FiltroEmpleados filtro, CancellationToken cancelacion = default);

    Task<ResultadoAltaEmpleado> AltaAsync(
        SolicitudAltaEmpleado solicitud,
        byte idCartera,
        string usuario,
        CancellationToken cancelacion = default);
}

/// <summary>Casos de uso de empleados: consulta y alta.</summary>
public interface IServicioEmpleados
{
    Task<IReadOnlyList<EmpleadoResumen>> ConsultarAsync(FiltroEmpleados filtro, CancellationToken cancelacion = default);

    Task<ResultadoAltaEmpleado> AltaAsync(SolicitudAltaEmpleado solicitud, CancellationToken cancelacion = default);
}
