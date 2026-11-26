using UnoContact.Crm.Application.Acceso;
namespace UnoContact.Crm.Application.Rh;

/// <summary>Acceso a los empleados del CRM (base única BABEL_UNIFICADA, esquema rh).</summary>
public interface IRepositorioEmpleados
{
    Task<IReadOnlyList<EmpleadoResumen>> ConsultarAsync(FiltroEmpleados filtro, CancellationToken cancelacion = default);

    /// <param name="ajustesPermisos">Ajustes contra el puesto ("clave:1,clave:0"); null = solo lo del puesto.</param>
    Task<ResultadoAltaEmpleado> AltaAsync(
        SolicitudAltaEmpleado solicitud,
        byte idCartera,
        string usuario,
        string? ajustesPermisos,
        CancellationToken cancelacion = default);

    /// <summary>Usuario del empleado, si es ROOT, su puesto y sus ajustes de permisos (null si no tiene usuario).</summary>
    Task<(int IdUsuario, bool EsRoot, short IdPuesto, IReadOnlyList<AjustePermiso> Ajustes)?> PermisosDeEmpleadoAsync(
        int idEmpleado, CancellationToken cancelacion = default);

    /// <summary>Empleados (activos o de baja) con el mismo nombre completo, sin importar mayúsculas ni acentos.</summary>
    Task<IReadOnlyList<EmpleadoCoincidente>> BuscarDuplicadosAsync(
        string nombre, string paterno, string materno, byte idCartera, CancellationToken cancelacion = default);

    /// <summary>Da acceso a la cartera a un empleado activo, sin moverlo de su cartera actual.</summary>
    Task DarAccesoCarteraAsync(int idEmpleado, byte idCartera, string usuario, CancellationToken cancelacion = default);

    /// <summary>Altas hechas en el sistema (bitácora) en la cartera, entre dos fechas (inclusivo).</summary>
    Task<IReadOnlyList<AltaRegistrada>> ConsultarAltasAsync(byte idCartera, DateOnly desde, DateOnly hasta, CancellationToken cancelacion = default);

    /// <summary>Edita nombre, puesto, sexo y horario de un empleado activo de la cartera.</summary>
    /// <param name="ajustesPermisos">null = no se cambian; "" = solo lo de su puesto.</param>
    Task EditarAsync(int idEmpleado, byte idCartera, SolicitudEdicionEmpleado solicitud, string usuario, string? ajustesPermisos, CancellationToken cancelacion = default);
}

/// <summary>Casos de uso de empleados: consulta y alta.</summary>
public interface IServicioEmpleados
{
    Task<IReadOnlyList<EmpleadoResumen>> ConsultarAsync(FiltroEmpleados filtro, CancellationToken cancelacion = default);

    Task<ResultadoAltaEmpleado> AltaAsync(SolicitudAltaEmpleado solicitud, CancellationToken cancelacion = default);

    /// <summary>Da acceso a la cartera activa de la sesión a un empleado que ya existe (en lugar de duplicarlo).</summary>
    Task DarAccesoCarteraAsync(int idEmpleado, CancellationToken cancelacion = default);

    /// <summary>Historial de altas de la cartera de la sesión. Sin fechas: la semana actual (lunes a hoy).</summary>
    Task<IReadOnlyList<AltaRegistrada>> ConsultarAltasAsync(DateOnly? desde, DateOnly? hasta, CancellationToken cancelacion = default);

    /// <summary>Edita el empleado (NUEVO: BABEL no tenía edición).</summary>
    Task EditarAsync(int idEmpleado, SolicitudEdicionEmpleado solicitud, CancellationToken cancelacion = default);

    /// <summary>Permisos actuales del empleado y si quien consulta los puede cambiar.</summary>
    Task<PermisosEmpleado> ConsultarPermisosAsync(int idEmpleado, CancellationToken cancelacion = default);
}
