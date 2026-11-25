using UnoContact.Crm.Application.Abstracciones;

namespace UnoContact.Crm.Application.Rh;

/// <summary>
/// Consulta y alta de empleados. Normaliza los datos antes de ir al repositorio.
/// El alta usa la cartera activa de la sesión y exige apellido materno, igual que el .exe.
/// El departamento no se captura: el procedimiento lo deriva de la cartera.
/// </summary>
public sealed class ServicioEmpleados(
    IRepositorioEmpleados repositorio,
    IUsuarioActual usuario) : IServicioEmpleados
{
    public Task<IReadOnlyList<EmpleadoResumen>> ConsultarAsync(FiltroEmpleados filtro, CancellationToken cancelacion = default)
    {
        var nombre = string.IsNullOrWhiteSpace(filtro.Nombre) ? null : filtro.Nombre.Trim();
        var normalizado = filtro with { Nombre = nombre };
        return repositorio.ConsultarAsync(normalizado, cancelacion);
    }

    public Task<ResultadoAltaEmpleado> AltaAsync(SolicitudAltaEmpleado solicitud, CancellationToken cancelacion = default)
    {
        var normalizada = solicitud with
        {
            Nombre = (solicitud.Nombre ?? string.Empty).Trim(),
            Paterno = (solicitud.Paterno ?? string.Empty).Trim(),
            Materno = (solicitud.Materno ?? string.Empty).Trim(),
        };

        if (normalizada.Nombre.Length == 0)
            throw new ArgumentException("Ingresa el nombre del empleado.", nameof(solicitud));
        if (normalizada.Paterno.Length == 0)
            throw new ArgumentException("Ingresa el apellido paterno del empleado.", nameof(solicitud));
        if (normalizada.Materno.Length == 0)
            throw new ArgumentException("Ingresa el apellido materno del empleado.", nameof(solicitud));

        if (usuario.IdCartera is < 1 or > 255)
            throw new InvalidOperationException("La sesión no tiene una cartera activa.");

        return repositorio.AltaAsync(
            normalizada,
            (byte)usuario.IdCartera,
            usuario.Usuario,
            cancelacion);
    }
}
