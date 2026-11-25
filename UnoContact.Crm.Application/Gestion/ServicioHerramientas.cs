using UnoContact.Crm.Application.Abstracciones;

namespace UnoContact.Crm.Application.Gestion;

/// <summary>
/// Casos de uso de Herramientas. La cartera y el empleado SIEMPRE vienen de la
/// sesión; el cliente nunca puede enviarlos. Equivale a los handlers Click del
/// MenuStrip de FRM_GESTION_CARTERA.
/// </summary>
public sealed class ServicioHerramientas(
    IRepositorioHerramientas repositorio,
    IUsuarioActual usuario) : IServicioHerramientas
{
    public Task<IReadOnlyList<NotaResumen>> ConsultarNotasAsync(long idCuenta, CancellationToken cancelacion = default)
    {
        ValidarCuenta(idCuenta);
        return repositorio.ConsultarNotasAsync(Cartera(), idCuenta, cancelacion);
    }

    public Task<ResultadoOperacion> RegistrarNotaAsync(SolicitudNota solicitud, CancellationToken cancelacion = default)
    {
        ValidarCuenta(solicitud.IdCuenta);
        var normalizada = solicitud with
        {
            TipoSeguimiento = Normalizar(solicitud.TipoSeguimiento),
            Telefono = Normalizar(solicitud.Telefono),
            Texto = Normalizar(solicitud.Texto),
            FechaSeguimiento = solicitud.FechaSeguimiento ?? DateTime.Now,
        };
        if (string.IsNullOrEmpty(normalizada.Texto))
            throw new ArgumentException("Captura el texto de la nota.", nameof(solicitud));

        return repositorio.RegistrarNotaAsync(normalizada, Cartera(), Empleado(), cancelacion);
    }

    public Task<BlocNotaDto> ConsultarBlocNotaAsync(CancellationToken cancelacion = default) =>
        repositorio.ConsultarBlocNotaAsync(Cartera(), Empleado(), cancelacion);

    public Task<ResultadoOperacion> GuardarBlocNotaAsync(string texto, CancellationToken cancelacion = default) =>
        repositorio.GuardarBlocNotaAsync(Cartera(), Empleado(), texto ?? string.Empty, cancelacion);

    public Task<RecesoActivo> IniciarRecesoAsync(string tipoReceso, CancellationToken cancelacion = default) =>
        repositorio.IniciarRecesoAsync(Cartera(), Empleado(), Normalizar(tipoReceso) ?? "Receso", cancelacion);

    public Task<ResultadoOperacion> FinalizarRecesoAsync(long idReceso, CancellationToken cancelacion = default)
    {
        if (idReceso <= 0) throw new ArgumentException("No hay un receso activo.", nameof(idReceso));
        return repositorio.FinalizarRecesoAsync(idReceso, Cartera(), Empleado(), cancelacion);
    }

    public Task<IReadOnlyList<RecesoResumen>> ConsultarRecesosAsync(CancellationToken cancelacion = default) =>
        repositorio.ConsultarRecesosAsync(Cartera(), Empleado(), cancelacion);

    public Task<IReadOnlyList<AgendaResumen>> ConsultarAgendaAsync(long? idCuenta, CancellationToken cancelacion = default)
    {
        if (idCuenta is < 1) ValidarCuenta(idCuenta.Value);
        return repositorio.ConsultarAgendaAsync(Cartera(), idCuenta, cancelacion);
    }

    public Task<ResultadoOperacion> RegistrarAgendaAsync(SolicitudAgenda solicitud, CancellationToken cancelacion = default)
    {
        ValidarCuenta(solicitud.IdCuenta);
        if (solicitud.FechaHora <= DateTime.Now)
            throw new ArgumentException("La fecha de la llamada debe ser futura.", nameof(solicitud));

        var normalizada = solicitud with
        {
            Telefono = Normalizar(solicitud.Telefono),
            Asunto = Normalizar(solicitud.Asunto),
        };
        return repositorio.RegistrarAgendaAsync(normalizada, Cartera(), Empleado(), cancelacion);
    }

    public Task<ResultadoOperacion> CambiarEstatusAgendaAsync(long idAgenda, string estatus, CancellationToken cancelacion = default)
    {
        if (idAgenda <= 0) throw new ArgumentException("Selecciona una llamada agendada.", nameof(idAgenda));
        var permitidos = new[] { "PENDIENTE", "REALIZADA", "CANCELADA" };
        var normalizado = (estatus ?? string.Empty).Trim().ToUpperInvariant();
        if (!permitidos.Contains(normalizado))
            throw new ArgumentException("Estatus de agenda no válido.", nameof(estatus));

        return repositorio.CambiarEstatusAgendaAsync(idAgenda, Cartera(), normalizado, cancelacion);
    }

    public Task<IReadOnlyList<NegociacionResumen>> ConsultarNegociacionesAsync(long idCuenta, CancellationToken cancelacion = default)
    {
        ValidarCuenta(idCuenta);
        return repositorio.ConsultarNegociacionesAsync(Cartera(), idCuenta, cancelacion);
    }

    public Task<ResultadoOperacion> RegistrarNegociacionAsync(SolicitudNegociacion solicitud, CancellationToken cancelacion = default)
    {
        ValidarCuenta(solicitud.IdCuenta);
        if (solicitud.MontoFinal <= 0)
            throw new ArgumentException("El monto final debe ser mayor a cero.", nameof(solicitud));
        if (solicitud.PorcentajeDescuento is < 0 or > 100)
            throw new ArgumentException("El descuento debe estar entre 0 y 100.", nameof(solicitud));

        var normalizada = solicitud with
        {
            TipoNegociacion = Normalizar(solicitud.TipoNegociacion) ?? "DESCUENTO",
            TipoPago = Normalizar(solicitud.TipoPago) ?? "PLAN DE PAGOS",
            Comentario = Normalizar(solicitud.Comentario),
        };
        return repositorio.RegistrarNegociacionAsync(normalizada, Cartera(), Empleado(), cancelacion);
    }

    public Task<ResultadoOperacion> ActualizarDemograficoAsync(
        SolicitudActualizaDemografico solicitud, CancellationToken cancelacion = default)
    {
        ValidarCuenta(solicitud.IdCuenta);
        var normalizada = solicitud with
        {
            Calle = Normalizar(solicitud.Calle),
            Colonia = Normalizar(solicitud.Colonia),
            CodigoPostal = Normalizar(solicitud.CodigoPostal),
            Delegacion = Normalizar(solicitud.Delegacion),
            Estado = Normalizar(solicitud.Estado),
            Telefono = Normalizar(solicitud.Telefono),
            Email = Normalizar(solicitud.Email),
        };
        if (normalizada.Email is not null && !normalizada.Email.Contains('@'))
            throw new ArgumentException("El correo electrónico no es válido.", nameof(solicitud));

        return repositorio.ActualizarDemograficoAsync(normalizada, Cartera(), usuario.Usuario, cancelacion);
    }

    private byte Cartera()
    {
        if (usuario.IdCartera is < 1 or > 255)
            throw new InvalidOperationException("La sesión no tiene una cartera activa.");
        return (byte)usuario.IdCartera;
    }

    private int Empleado()
    {
        if (usuario.IdEmpleado <= 0)
            throw new InvalidOperationException("La sesión no tiene un empleado válido.");
        return usuario.IdEmpleado;
    }

    private static void ValidarCuenta(long idCuenta)
    {
        if (idCuenta <= 0) throw new ArgumentException("Selecciona una cuenta de la cartera.", nameof(idCuenta));
    }

    private static string? Normalizar(string? valor) =>
        string.IsNullOrWhiteSpace(valor) ? null : valor.Trim();
}
