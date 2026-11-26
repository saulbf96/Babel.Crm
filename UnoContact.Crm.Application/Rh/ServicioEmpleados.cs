using UnoContact.Crm.Application.Abstracciones;
using UnoContact.Crm.Application.Acceso;
using Microsoft.Extensions.Options;

namespace UnoContact.Crm.Application.Rh;

/// <summary>
/// Consulta y alta de empleados. Normaliza los datos antes de ir al repositorio.
/// El alta usa la cartera activa de la sesión y exige apellido materno, igual que el .exe.
/// El departamento no se captura: el procedimiento lo deriva de la cartera.
/// </summary>
public sealed class ServicioEmpleados(
    IRepositorioEmpleados repositorio,
    IUsuarioActual usuario,
    IOptions<MapeoPerfiles>? mapeo = null,
    Carteras.IServicioCarteras? carteras = null) : IServicioEmpleados
{
    public Task<IReadOnlyList<EmpleadoResumen>> ConsultarAsync(FiltroEmpleados filtro, CancellationToken cancelacion = default)
    {
        var nombre = string.IsNullOrWhiteSpace(filtro.Nombre) ? null : filtro.Nombre.Trim();
        var normalizado = filtro with { Nombre = nombre };
        return repositorio.ConsultarAsync(normalizado, cancelacion);
    }

    public async Task<ResultadoAltaEmpleado> AltaAsync(SolicitudAltaEmpleado solicitud, CancellationToken cancelacion = default)
    {
        // Solo letras y espacios, en mayúsculas (ReglasNombre). BABEL aceptaba cualquier cosa.
        var normalizada = solicitud with
        {
            Nombre = ReglasNombre.Validar(solicitud.Nombre, "nombre"),
            Paterno = ReglasNombre.Validar(solicitud.Paterno, "apellido paterno"),
            Materno = ReglasNombre.Validar(solicitud.Materno, "apellido materno"),
        };

        normalizada = normalizada with { AplicaHorario = ValidarHorario(normalizada.HoraEntrada, normalizada.HoraSalida, normalizada.AplicaHorario) };

        // Multi-campaña: una principal (con la que entra) + las demás como acceso.
        var sesion = Cartera();
        var elegidas = (normalizada.Carteras is { Count: > 0 } c ? c : [sesion]).Distinct().ToList();
        var principal = normalizada.CarteraPrincipal ?? (elegidas.Contains(sesion) ? sesion : elegidas[0]);
        if (!elegidas.Contains(principal))
            throw new ArgumentException("La campaña principal debe ser una de las campañas elegidas.");
        if (carteras is not null)
        {
            foreach (var id in elegidas)
            {
                if (await carteras.ValidarAsync(id, cancelacion) is null)
                    throw new ArgumentException("No tienes acceso a una de las campañas elegidas.");
            }
        }
        normalizada = normalizada with { Carteras = elegidas, CarteraPrincipal = principal };
        var idCartera = principal;

        // BABEL da de alta otra vez a la misma persona por cartera o reingreso. Aquí, si ya
        // existe, NO se da de alta: se regresan las coincidencias para moverla, darle acceso
        // o reactivarla. Solo con ConfirmarHomonimo (otra persona, mismo nombre) se continúa.
        if (!normalizada.ConfirmarHomonimo)
        {
            var coincidencias = await repositorio.BuscarDuplicadosAsync(
                normalizada.Nombre, normalizada.Paterno, normalizada.Materno, idCartera, cancelacion);
            if (coincidencias.Count > 0)
            {
                return new ResultadoAltaEmpleado(
                    0,
                    "Ya existe un empleado con ese nombre. No se dio de alta.",
                    coincidencias);
            }
        }

        // Permisos: si el admin los ajustó, se guardan solo las diferencias contra el puesto.
        string? ajustes = null;
        if (normalizada.Permisos is { } deseados)
        {
            var baseDelPuesto = ReglasPermisos.Base(PerfilesDe(normalizada.IdPuesto), esRoot: false);
            baseDelPuesto.Add(ReglasPermisos.Inicio);
            var error = ReglasPermisos.ValidarCambio(
                usuario.Perfiles, usuario.EsRoot, usuario.Permisos.ToHashSet(), usuario.IdUsuario, null, baseDelPuesto, deseados);
            if (error is not null) throw new ArgumentException(error);
            ajustes = ReglasPermisos.Serializar(ReglasPermisos.Ajustes(baseDelPuesto, deseados));
        }

        return await repositorio.AltaAsync(normalizada, idCartera, usuario.Usuario, ajustes, cancelacion);
    }

    public Task DarAccesoCarteraAsync(int idEmpleado, CancellationToken cancelacion = default) =>
        repositorio.DarAccesoCarteraAsync(idEmpleado, Cartera(), usuario.Usuario, cancelacion);

    public const int RangoMaximoDias = 366;

    /// <summary>Lunes de la semana de la fecha dada.</summary>
    public static DateOnly LunesDe(DateOnly fecha) =>
        fecha.AddDays(-(((int)fecha.DayOfWeek + 6) % 7));

    public Task<IReadOnlyList<AltaRegistrada>> ConsultarAltasAsync(DateOnly? desde, DateOnly? hasta, CancellationToken cancelacion = default)
    {
        var hoy = DateOnly.FromDateTime(DateTime.Today);
        var h = hasta ?? hoy;
        var d = desde ?? LunesDe(hoy); // por defecto: la semana actual
        if (h > hoy || d > hoy)
            throw new ArgumentException("No se pueden consultar fechas futuras: usa hoy o días anteriores.");
        if (d > h)
            throw new ArgumentException("Revisa el rango: \"Desde\" no puede ser mayor que \"Hasta\".");
        if (h.DayNumber - d.DayNumber > RangoMaximoDias)
            throw new ArgumentException("El rango no puede ser mayor a un año.");
        return repositorio.ConsultarAltasAsync(Cartera(), d, h, cancelacion);
    }

    public async Task EditarAsync(int idEmpleado, SolicitudEdicionEmpleado solicitud, CancellationToken cancelacion = default)
    {
        var s = solicitud with
        {
            Nombre = ReglasNombre.Validar(solicitud.Nombre, "nombre"),
            Paterno = ReglasNombre.Validar(solicitud.Paterno, "apellido paterno"),
            Materno = ReglasNombre.Validar(solicitud.Materno, "apellido materno"),
        };

        s = s with { AplicaHorario = ValidarHorario(s.HoraEntrada, s.HoraSalida, s.AplicaHorario) };

        string? ajustes = null;
        if (s.Permisos is { } deseados)
        {
            var destino = await repositorio.PermisosDeEmpleadoAsync(idEmpleado, cancelacion);
            if (destino is { } d)
            {
                var actual = ReglasPermisos.Efectivos(PerfilesDe(d.IdPuesto), d.EsRoot, d.Ajustes);
                var error = ReglasPermisos.ValidarCambio(
                    usuario.Perfiles, usuario.EsRoot, usuario.Permisos.ToHashSet(), usuario.IdUsuario, d.IdUsuario, actual, deseados);
                if (error is not null) throw new ArgumentException(error);
                var baseNueva = ReglasPermisos.Base(PerfilesDe(s.IdPuesto), d.EsRoot);
                baseNueva.Add(ReglasPermisos.Inicio);
                ajustes = ReglasPermisos.Serializar(ReglasPermisos.Ajustes(baseNueva, deseados));
            }
        }

        await repositorio.EditarAsync(idEmpleado, Cartera(), s, usuario.Usuario, ajustes, cancelacion);
    }

    public async Task<PermisosEmpleado> ConsultarPermisosAsync(int idEmpleado, CancellationToken cancelacion = default)
    {
        var destino = await repositorio.PermisosDeEmpleadoAsync(idEmpleado, cancelacion);
        if (destino is not { } d)
            return new PermisosEmpleado(false, false, false, false, "No tiene usuario.", []);

        var permisos = ReglasPermisos.Efectivos(PerfilesDe(d.IdPuesto), d.EsRoot, d.Ajustes)
            .Where(p => p != ReglasPermisos.Inicio).OrderBy(p => p).ToList();
        var esUstedMismo = d.IdUsuario == usuario.IdUsuario;
        string? motivo = null;
        if (!ReglasPermisos.PuedeAdministrar(usuario.Perfiles, usuario.EsRoot))
            motivo = "Solo un administrador puede cambiar permisos.";
        else if (esUstedMismo && !usuario.EsRoot)
            motivo = "No puedes cambiar tus propios permisos; pídelo a otro administrador.";
        return new PermisosEmpleado(true, d.EsRoot, esUstedMismo, motivo is null, motivo, permisos);
    }

    private IReadOnlyCollection<Domain.Seguridad.Perfil> PerfilesDe(short idPuesto) =>
        mapeo?.Value.PerfilesDe(idPuesto) ?? [];

    public const int JornadaMinimaMinutos = 60;
    public const int JornadaMaximaMinutos = 12 * 60;

    /// <summary>
    /// Minutos de jornada. Si la salida es antes que la entrada, cruza la medianoche
    /// (ej. 22:00 a 06:00 = 8 h), como el turno nocturno.
    /// </summary>
    public static int MinutosJornada(TimeOnly entrada, TimeOnly salida)
    {
        var minutos = (int)(salida - entrada).TotalMinutes; // TimeOnly ya da la diferencia "hacia adelante"
        return minutos;
    }

    /// <summary>
    /// Reglas del horario (iguales a rh.USP_VALIDA_HORARIO). Regresa si aplica horario:
    /// sin las dos horas no aplica; con una sola es error; con las dos, jornada de 1 a 12 h.
    /// </summary>
    public static bool ValidarHorario(TimeOnly? entrada, TimeOnly? salida, bool aplicaHorario)
    {
        if (entrada is null && salida is null)
            return false;
        if (entrada is null || salida is null)
            throw new ArgumentException("Captura la hora de entrada y la hora de salida, o deja las dos vacías si no aplica horario.");

        var minutos = MinutosJornada(entrada.Value, salida.Value);
        if (minutos < JornadaMinimaMinutos || minutos > JornadaMaximaMinutos)
            throw new ArgumentException("La jornada debe durar entre 1 y 12 horas. Revisa la hora de entrada y de salida.");

        return aplicaHorario;
    }

    private byte Cartera() =>
        usuario.IdCartera is >= 1 and <= 255
            ? (byte)usuario.IdCartera
            : throw new InvalidOperationException("La sesión no tiene una cartera activa.");
}
