using UnoContact.Crm.Application.Abstracciones;

namespace UnoContact.Crm.Application.Gestion;

/// <summary>
/// Casos de uso iniciales de Gestión. La cartera SIEMPRE viene de la sesión:
/// el cliente no puede enviar idCartera ni consultar cuentas de otra cartera.
/// </summary>
public sealed class ServicioGestion(
    IRepositorioGestion repositorio,
    IUsuarioActual usuario) : IServicioGestion
{
    public Task<IReadOnlyList<TipoGestionDto>> ConsultarTiposAsync(CancellationToken cancelacion = default) =>
        repositorio.ConsultarTiposAsync(cancelacion);

    public Task<IReadOnlyList<CuentaResumen>> ConsultarCuentasAsync(
        string? texto, CancellationToken cancelacion = default) =>
        repositorio.ConsultarCuentasAsync(Cartera(), Normalizar(texto), cancelacion);

    public Task<ResultadoCuenta> CrearCuentaAsync(
        SolicitudCuenta solicitud, CancellationToken cancelacion = default)
    {
        if (solicitud.IdControlLegacy <= 0)
            throw new ArgumentException("El ID de control es obligatorio.", nameof(solicitud));

        var normalizada = solicitud with
        {
            NumeroCuenta = (solicitud.NumeroCuenta ?? string.Empty).Trim(),
            NombreCliente = Normalizar(solicitud.NombreCliente),
            SituacionCuenta = Normalizar(solicitud.SituacionCuenta),
            RazonMora = Normalizar(solicitud.RazonMora),
        };

        if (normalizada.NumeroCuenta.Length == 0)
            throw new ArgumentException("Ingresa el número de cuenta.", nameof(solicitud));

        var idEmpleado = usuario.IdEmpleado > 0 ? usuario.IdEmpleado : (int?)null;
        return repositorio.CrearCuentaAsync(
            normalizada, Cartera(), idEmpleado, usuario.Usuario, cancelacion);
    }

    public Task<CuentaDetalle?> ConsultarCuentaAsync(
        long idCuenta, CancellationToken cancelacion = default)
    {
        ValidarId(idCuenta);
        return repositorio.ConsultarCuentaAsync(Cartera(), idCuenta, cancelacion);
    }

    public Task<IReadOnlyList<TelefonoResumen>> ConsultarTelefonosAsync(
        long idCuenta, CancellationToken cancelacion = default)
    {
        ValidarId(idCuenta);
        return repositorio.ConsultarTelefonosAsync(Cartera(), idCuenta, cancelacion);
    }

    public Task<ResultadoOperacion> RegistrarTelefonoAsync(
        long idCuenta, SolicitudTelefono solicitud, CancellationToken cancelacion = default)
    {
        ValidarId(idCuenta);
        var normalizada = solicitud with
        {
            Numero = (solicitud.Numero ?? string.Empty).Trim(),
            Tipo = Normalizar(solicitud.Tipo),
            Origen = Normalizar(solicitud.Origen),
        };
        if (normalizada.Numero.Length == 0)
            throw new ArgumentException("Ingresa el teléfono.", nameof(solicitud));

        return repositorio.RegistrarTelefonoAsync(
            normalizada, Cartera(), idCuenta, usuario.Usuario, cancelacion);
    }

    public Task<IReadOnlyList<GestionResumen>> ConsultarGestionesAsync(
        long idCuenta, CancellationToken cancelacion = default)
    {
        ValidarId(idCuenta);
        return repositorio.ConsultarGestionesAsync(Cartera(), idCuenta, cancelacion);
    }

    public Task<ResultadoOperacion> RegistrarGestionAsync(
        SolicitudGestion solicitud, CancellationToken cancelacion = default)
    {
        ValidarId(solicitud.IdCuenta);
        if (usuario.IdEmpleado <= 0)
            throw new InvalidOperationException("La sesión no tiene un empleado válido.");

        var comentario = Normalizar(solicitud.Comentario);
        var telefonoMarcado = Normalizar(solicitud.TelefonoMarcado);
        if (comentario is null && solicitud.IdTelefono is null && telefonoMarcado is null)
            throw new ArgumentException("Captura un comentario o selecciona un teléfono.", nameof(solicitud));

        var normalizada = solicitud with
        {
            Comentario = comentario,
            TelefonoMarcado = telefonoMarcado,
        };
        return repositorio.RegistrarGestionAsync(
            normalizada, Cartera(), usuario.IdEmpleado, usuario.Usuario, cancelacion);
    }

    public Task<IReadOnlyList<PromesaResumen>> ConsultarPromesasAsync(
        long idCuenta, CancellationToken cancelacion = default)
    {
        ValidarId(idCuenta);
        return repositorio.ConsultarPromesasAsync(Cartera(), idCuenta, cancelacion);
    }

    public Task<ResultadoOperacion> RegistrarPromesaAsync(
        SolicitudPromesa solicitud, CancellationToken cancelacion = default)
    {
        ValidarId(solicitud.IdCuenta);
        if (solicitud.Monto <= 0)
            throw new ArgumentException("El monto de la promesa debe ser mayor a cero.", nameof(solicitud));
        if (solicitud.FechaPromesa < DateOnly.FromDateTime(DateTime.Today))
            throw new ArgumentException("La fecha de promesa no puede ser anterior a hoy.", nameof(solicitud));

        var normalizada = solicitud with
        {
            LugarPago = Normalizar(solicitud.LugarPago),
            FuenteIngreso = Normalizar(solicitud.FuenteIngreso),
            RazonMora = Normalizar(solicitud.RazonMora),
            Notas = Normalizar(solicitud.Notas),
        };
        return repositorio.RegistrarPromesaAsync(normalizada, Cartera(), usuario.Usuario, cancelacion);
    }

    public Task<IReadOnlyList<DemograficoResumen>> ConsultarDemograficosAsync(
        long idCuenta, CancellationToken cancelacion = default)
    {
        ValidarId(idCuenta);
        return repositorio.ConsultarDemograficosAsync(Cartera(), idCuenta, cancelacion);
    }

    private byte Cartera()
    {
        if (usuario.IdCartera is < 1 or > 255)
            throw new InvalidOperationException("La sesión no tiene una cartera activa.");
        return (byte)usuario.IdCartera;
    }

    private static void ValidarId(long idCuenta)
    {
        if (idCuenta <= 0)
            throw new ArgumentException("Selecciona una cuenta de la cartera.", nameof(idCuenta));
    }

    private static string? Normalizar(string? valor) =>
        string.IsNullOrWhiteSpace(valor) ? null : valor.Trim();
}
