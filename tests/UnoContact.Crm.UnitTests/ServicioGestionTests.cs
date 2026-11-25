using UnoContact.Crm.Application.Abstracciones;
using UnoContact.Crm.Application.Gestion;
using UnoContact.Crm.Domain.Seguridad;

namespace UnoContact.Crm.UnitTests;

public sealed class ServicioGestionTests
{
    [Fact]
    public async Task Consultar_cuentas_usa_la_cartera_de_la_sesion()
    {
        var repositorio = new RepositorioFalso();
        var servicio = new ServicioGestion(repositorio, Usuario(7, 3));

        await servicio.ConsultarCuentasAsync("  cuenta  ");

        Assert.Equal(3, repositorio.IdCartera);
        Assert.Equal("cuenta", repositorio.Texto);
    }

    [Fact]
    public async Task Registrar_gestion_usa_empleado_y_cartera_de_la_sesion()
    {
        var repositorio = new RepositorioFalso();
        var servicio = new ServicioGestion(repositorio, Usuario(42, 5));

        await servicio.RegistrarGestionAsync(new SolicitudGestion(
            IdCuenta: 9,
            IdTipoGestion: 1,
            Comentario: "  Cliente localizado  ",
            IdTelefono: null,
            TelefonoMarcado: "  5544332211  ",
            Inbound: false,
            TiempoLlamadaSegundos: 30,
            TiempoEscrituraSegundos: 20));

        Assert.Equal(5, repositorio.IdCartera);
        Assert.Equal(42, repositorio.IdEmpleado);
        Assert.Equal("Cliente localizado", repositorio.Comentario);
        Assert.Equal("5544332211", repositorio.TelefonoMarcado);
    }

    [Fact]
    public async Task Registrar_promesa_rechaza_monto_cero_antes_de_llamar_al_repositorio()
    {
        var repositorio = new RepositorioFalso();
        var servicio = new ServicioGestion(repositorio, Usuario(42, 1));

        await Assert.ThrowsAsync<ArgumentException>(() => servicio.RegistrarPromesaAsync(
            new SolicitudPromesa(
                IdCuenta: 1,
                IdGestion: null,
                Monto: 0,
                FechaPromesa: DateOnly.FromDateTime(DateTime.Today),
                LugarPago: null,
                FuenteIngreso: null,
                RazonMora: null,
                Notas: null)));

        Assert.False(repositorio.PromesaRegistrada);
    }

    [Fact]
    public async Task Sin_cartera_activa_no_consulta_cuentas()
    {
        var repositorio = new RepositorioFalso();
        var servicio = new ServicioGestion(repositorio, Usuario(1, 0));

        await Assert.ThrowsAsync<InvalidOperationException>(() => servicio.ConsultarCuentasAsync(null));
        Assert.False(repositorio.Consulto);
    }

    private static UsuarioFalso Usuario(int idEmpleado, int idCartera) =>
        new(idEmpleado, idCartera);

    private sealed class UsuarioFalso(int idEmpleado, int idCartera) : IUsuarioActual
    {
        public bool EstaAutenticado => true;
        public int IdEmpleado { get; } = idEmpleado;
        public int IdUsuario => 1;
        public string Usuario => "ASESOR";
        public int IdCartera { get; } = idCartera;
        public string Cartera => "BANCO_AZTECA";
        public IReadOnlyCollection<Perfil> Perfiles => [Perfil.Asesor];
    }

    private sealed class RepositorioFalso : IRepositorioGestion
    {
        public byte IdCartera { get; private set; }
        public int IdEmpleado { get; private set; }
        public string? Texto { get; private set; }
        public string? Comentario { get; private set; }
        public string? TelefonoMarcado { get; private set; }
        public bool Consulto { get; private set; }
        public bool PromesaRegistrada { get; private set; }

        public Task<IReadOnlyList<TipoGestionDto>> ConsultarTiposAsync(CancellationToken cancelacion = default) =>
            Task.FromResult<IReadOnlyList<TipoGestionDto>>([]);

        public Task<IReadOnlyList<CuentaResumen>> ConsultarCuentasAsync(
            byte idCartera, string? texto, CancellationToken cancelacion = default)
        {
            Consulto = true;
            IdCartera = idCartera;
            Texto = texto;
            return Task.FromResult<IReadOnlyList<CuentaResumen>>([]);
        }

        public Task<ResultadoCuenta> CrearCuentaAsync(
            SolicitudCuenta solicitud, byte idCartera, int? idEmpleado, string usuario,
            CancellationToken cancelacion = default) =>
            Task.FromResult(new ResultadoCuenta(1, "Cuenta capturada."));

        public Task<CuentaDetalle?> ConsultarCuentaAsync(
            byte idCartera, long idCuenta, CancellationToken cancelacion = default) =>
            Task.FromResult<CuentaDetalle?>(null);

        public Task<IReadOnlyList<TelefonoResumen>> ConsultarTelefonosAsync(
            byte idCartera, long idCuenta, CancellationToken cancelacion = default) =>
            Task.FromResult<IReadOnlyList<TelefonoResumen>>([]);

        public Task<ResultadoOperacion> RegistrarTelefonoAsync(
            SolicitudTelefono solicitud, byte idCartera, long idCuenta, string usuario,
            CancellationToken cancelacion = default) =>
            Task.FromResult(new ResultadoOperacion(1, "Teléfono capturado."));

        public Task<IReadOnlyList<GestionResumen>> ConsultarGestionesAsync(
            byte idCartera, long idCuenta, CancellationToken cancelacion = default) =>
            Task.FromResult<IReadOnlyList<GestionResumen>>([]);

        public Task<ResultadoOperacion> RegistrarGestionAsync(
            SolicitudGestion solicitud, byte idCartera, int idEmpleado, string usuario,
            CancellationToken cancelacion = default)
        {
            IdCartera = idCartera;
            IdEmpleado = idEmpleado;
            Comentario = solicitud.Comentario;
            TelefonoMarcado = solicitud.TelefonoMarcado;
            return Task.FromResult(new ResultadoOperacion(1, "Gestión registrada."));
        }

        public Task<IReadOnlyList<PromesaResumen>> ConsultarPromesasAsync(
            byte idCartera, long idCuenta, CancellationToken cancelacion = default) =>
            Task.FromResult<IReadOnlyList<PromesaResumen>>([]);

        public Task<ResultadoOperacion> RegistrarPromesaAsync(
            SolicitudPromesa solicitud, byte idCartera, string usuario,
            CancellationToken cancelacion = default)
        {
            PromesaRegistrada = true;
            return Task.FromResult(new ResultadoOperacion(1, "Promesa registrada."));
        }

        public Task<IReadOnlyList<DemograficoResumen>> ConsultarDemograficosAsync(
            byte idCartera, long idCuenta, CancellationToken cancelacion = default) =>
            Task.FromResult<IReadOnlyList<DemograficoResumen>>([]);
    }
}
