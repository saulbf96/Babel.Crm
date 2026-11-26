using UnoContact.Crm.Application.Acceso;
using UnoContact.Crm.Application.Abstracciones;
using UnoContact.Crm.Application.Rh;
using UnoContact.Crm.Domain.Seguridad;

namespace UnoContact.Crm.UnitTests;

/// <summary>
/// Verifica la paridad del Alta con el .exe: la cartera sale de la sesión y el materno es obligatorio.
/// </summary>
public sealed class ServicioEmpleadosTests
{
    private static readonly TimeOnly? Entrada = new TimeOnly(8, 0);
    private static readonly TimeOnly? Salida = new TimeOnly(14, 30);

    [Theory]
    [InlineData(8, 0, 14, 30, 390)]  // horario por defecto: 6 h 30 min
    [InlineData(22, 0, 6, 0, 480)]   // nocturno: cruza la medianoche
    public void Jornada_se_calcula_incluso_cruzando_la_medianoche(int he, int me, int hs, int ms, int minutos)
    {
        Assert.Equal(minutos, ServicioEmpleados.MinutosJornada(new TimeOnly(he, me), new TimeOnly(hs, ms)));
    }

    [Theory]
    [InlineData(9, 0, 9, 0)]    // misma hora
    [InlineData(9, 0, 9, 30)]   // menos de 1 hora
    [InlineData(9, 0, 6, 0)]    // 21 horas: error de dedo (quiso decir 18:00)
    public async Task Horario_invalido_se_rechaza_sin_dar_de_alta(int he, int me, int hs, int ms)
    {
        var repositorio = new RepositorioEmpleadosFalso();
        var servicio = new ServicioEmpleados(repositorio, new UsuarioActualFalso());

        await Assert.ThrowsAsync<ArgumentException>(() => servicio.AltaAsync(
            new SolicitudAltaEmpleado(14, 1, new TimeOnly(he, me), new TimeOnly(hs, ms), "PRUEBA", "FLUJO", "LOPEZ")));

        Assert.Null(repositorio.SolicitudRecibida);
    }

    [Fact]
    public async Task Alta_sin_horario_se_rechaza()
    {
        var servicio = new ServicioEmpleados(new RepositorioEmpleadosFalso(), new UsuarioActualFalso());

        await Assert.ThrowsAsync<ArgumentException>(() => servicio.AltaAsync(
            new SolicitudAltaEmpleado(14, 1, null, Salida, "PRUEBA", "FLUJO", "LOPEZ")));
    }

    [Fact]
    public async Task Alta_usa_la_cartera_de_la_sesion_y_normaliza_nombres()
    {
        var repositorio = new RepositorioEmpleadosFalso();
        var servicio = new ServicioEmpleados(repositorio, new UsuarioActualFalso { IdCartera = 7 });

        var resultado = await servicio.AltaAsync(
            new SolicitudAltaEmpleado(14, 1, Entrada, Salida, "  PRUEBA  ", "  FLUJO  ", "  LOPEZ  "));

        Assert.Equal(7, repositorio.IdCarteraRecibido);
        Assert.Equal("ADMIN", repositorio.UsuarioRecibido);
        Assert.Equal("PRUEBA", repositorio.SolicitudRecibida?.Nombre);
        Assert.Equal("FLUJO", repositorio.SolicitudRecibida?.Paterno);
        Assert.Equal("LOPEZ", repositorio.SolicitudRecibida?.Materno);
        Assert.Equal(1, resultado.IdEmpleado);
    }

    [Fact]
    public async Task Alta_sin_materno_se_rechaza_sin_llamar_al_repositorio()
    {
        var repositorio = new RepositorioEmpleadosFalso();
        var servicio = new ServicioEmpleados(repositorio, new UsuarioActualFalso());

        await Assert.ThrowsAsync<ArgumentException>(() => servicio.AltaAsync(
            new SolicitudAltaEmpleado(14, 1, Entrada, Salida, "PRUEBA", "FLUJO", "   ")));

        Assert.Null(repositorio.SolicitudRecibida);
    }

    private static readonly EmpleadoCoincidente Existente =
        new(304, "PRUEBA FLUJO LOPEZ", "EJECUTIVO", true, new DateOnly(2025, 9, 18), "OTRA_CARTERA", false, false, "PFLUJO");

    [Fact]
    public async Task Alta_de_persona_que_ya_existe_no_se_registra_y_regresa_coincidencias()
    {
        var repositorio = new RepositorioEmpleadosFalso { Coincidencias = [Existente] };
        var servicio = new ServicioEmpleados(repositorio, new UsuarioActualFalso { IdCartera = 7 });

        var resultado = await servicio.AltaAsync(new SolicitudAltaEmpleado(14, 1, Entrada, Salida, "Prueba", "Flujo", "Lopez"));

        Assert.Equal(0, resultado.IdEmpleado);
        Assert.Single(resultado.Coincidencias!);
        Assert.Null(repositorio.SolicitudRecibida); // NO se dio de alta
        Assert.Equal((byte)7, repositorio.IdCarteraBusqueda);
    }

    [Fact]
    public async Task Alta_de_homonimo_confirmado_si_se_registra()
    {
        var repositorio = new RepositorioEmpleadosFalso { Coincidencias = [Existente] };
        var servicio = new ServicioEmpleados(repositorio, new UsuarioActualFalso());

        var resultado = await servicio.AltaAsync(
            new SolicitudAltaEmpleado(14, 1, Entrada, Salida, "Prueba", "Flujo", "Lopez", ConfirmarHomonimo: true));

        Assert.Equal(1, resultado.IdEmpleado);
        Assert.NotNull(repositorio.SolicitudRecibida);
        Assert.Null(repositorio.IdCarteraBusqueda); // ni siquiera busca
    }

    [Fact]
    public async Task Dar_acceso_usa_la_cartera_de_la_sesion()
    {
        var repositorio = new RepositorioEmpleadosFalso();
        var servicio = new ServicioEmpleados(repositorio, new UsuarioActualFalso { IdCartera = 9 });

        await servicio.DarAccesoCarteraAsync(304);

        Assert.Equal((304, (byte)9, "ADMIN"), repositorio.AccesoOtorgado);
    }

    [Fact]
    public async Task Alta_sin_horas_queda_como_no_aplica_horario()
    {
        var repositorio = new RepositorioEmpleadosFalso();
        var servicio = new ServicioEmpleados(repositorio, new UsuarioActualFalso());

        await servicio.AltaAsync(new SolicitudAltaEmpleado(14, 1, null, null, "PRUEBA", "FLUJO", "LOPEZ"));

        Assert.False(repositorio.SolicitudRecibida!.AplicaHorario);
    }

    [Fact]
    public async Task Editar_usa_la_cartera_de_la_sesion_y_valida_horario()
    {
        var repositorio = new RepositorioEmpleadosFalso();
        var servicio = new ServicioEmpleados(repositorio, new UsuarioActualFalso { IdCartera = 5 });

        await servicio.EditarAsync(10, new SolicitudEdicionEmpleado(" ANA ", "PEREZ", "LOPEZ", 14, 2, new TimeOnly(15, 0), new TimeOnly(21, 30)));

        Assert.Equal((byte)5, repositorio.EdicionCartera);
        Assert.Equal("ANA", repositorio.Edicion!.Nombre);
        Assert.True(repositorio.Edicion.AplicaHorario);

        await Assert.ThrowsAsync<ArgumentException>(() => servicio.EditarAsync(10,
            new SolicitudEdicionEmpleado("ANA", "PEREZ", "LOPEZ", 14, 2, new TimeOnly(15, 0), null)));
    }

    [Fact]
    public async Task Historial_de_altas_por_defecto_es_la_semana_actual()
    {
        var repositorio = new RepositorioEmpleadosFalso();
        var servicio = new ServicioEmpleados(repositorio, new UsuarioActualFalso());
        var hoy = DateOnly.FromDateTime(DateTime.Today);

        await servicio.ConsultarAltasAsync(null, null);

        Assert.Equal(ServicioEmpleados.LunesDe(hoy), repositorio.RangoAltas!.Value.Desde);
        Assert.Equal(DayOfWeek.Monday, repositorio.RangoAltas.Value.Desde.DayOfWeek);
        Assert.Equal(hoy, repositorio.RangoAltas.Value.Hasta);
    }

    [Fact]
    public async Task Historial_de_altas_valida_el_rango()
    {
        var servicio = new ServicioEmpleados(new RepositorioEmpleadosFalso(), new UsuarioActualFalso());
        var hoy = DateOnly.FromDateTime(DateTime.Today);

        await Assert.ThrowsAsync<ArgumentException>(() => servicio.ConsultarAltasAsync(hoy, hoy.AddDays(-1)));   // al revés
        await Assert.ThrowsAsync<ArgumentException>(() => servicio.ConsultarAltasAsync(hoy.AddDays(-400), hoy)); // > 1 año
        await Assert.ThrowsAsync<ArgumentException>(() => servicio.ConsultarAltasAsync(hoy, hoy.AddDays(1)));    // mañana
        await Assert.ThrowsAsync<ArgumentException>(() => servicio.ConsultarAltasAsync(hoy.AddDays(30), hoy.AddDays(60))); // diciembre
    }

    [Fact]
    public async Task Historial_de_altas_permite_un_solo_dia_y_rangos_hacia_atras()
    {
        var repositorio = new RepositorioEmpleadosFalso();
        var servicio = new ServicioEmpleados(repositorio, new UsuarioActualFalso());
        var hoy = DateOnly.FromDateTime(DateTime.Today);

        await servicio.ConsultarAltasAsync(hoy, hoy);                 // solo hoy
        Assert.Equal((hoy, hoy), repositorio.RangoAltas);
        await servicio.ConsultarAltasAsync(hoy.AddDays(-56), hoy);    // de octubre a hoy
        Assert.Equal((hoy.AddDays(-56), hoy), repositorio.RangoAltas);
    }

    private sealed class RepositorioEmpleadosFalso : IRepositorioEmpleados
    {
        public SolicitudEdicionEmpleado? Edicion { get; private set; }

        public (DateOnly Desde, DateOnly Hasta)? RangoAltas { get; private set; }

        public Task<IReadOnlyList<AltaRegistrada>> ConsultarAltasAsync(byte idCartera, DateOnly desde, DateOnly hasta, CancellationToken cancelacion = default)
        {
            RangoAltas = (desde, hasta);
            return Task.FromResult<IReadOnlyList<AltaRegistrada>>([]);
        }

        public byte? EdicionCartera { get; private set; }

        public string? AjustesAlta { get; private set; }

        public (int IdUsuario, bool EsRoot, short IdPuesto, IReadOnlyList<AjustePermiso> Ajustes)? Destino { get; set; }

        public Task<(int IdUsuario, bool EsRoot, short IdPuesto, IReadOnlyList<AjustePermiso> Ajustes)?> PermisosDeEmpleadoAsync(
            int idEmpleado, CancellationToken cancelacion = default) => Task.FromResult(Destino);

        public Task EditarAsync(int idEmpleado, byte idCartera, SolicitudEdicionEmpleado solicitud, string usuario, string? ajustesPermisos, CancellationToken cancelacion = default)
        {
            Edicion = solicitud;
            EdicionCartera = idCartera;
            return Task.CompletedTask;
        }

        public IReadOnlyList<EmpleadoCoincidente> Coincidencias { get; init; } = [];

        public byte? IdCarteraBusqueda { get; private set; }

        public (int, byte, string)? AccesoOtorgado { get; private set; }

        public Task<IReadOnlyList<EmpleadoCoincidente>> BuscarDuplicadosAsync(
            string nombre, string paterno, string materno, byte idCartera, CancellationToken cancelacion = default)
        {
            IdCarteraBusqueda = idCartera;
            return Task.FromResult(Coincidencias);
        }

        public Task DarAccesoCarteraAsync(int idEmpleado, byte idCartera, string usuario, CancellationToken cancelacion = default)
        {
            AccesoOtorgado = (idEmpleado, idCartera, usuario);
            return Task.CompletedTask;
        }

        public byte IdCarteraRecibido { get; private set; }

        public string? UsuarioRecibido { get; private set; }

        public SolicitudAltaEmpleado? SolicitudRecibida { get; private set; }

        public Task<IReadOnlyList<EmpleadoResumen>> ConsultarAsync(
            FiltroEmpleados filtro, CancellationToken cancelacion = default) =>
            Task.FromResult<IReadOnlyList<EmpleadoResumen>>(Array.Empty<EmpleadoResumen>());

        public Task<ResultadoAltaEmpleado> AltaAsync(
            SolicitudAltaEmpleado solicitud,
            byte idCartera,
            string usuario,
            string? ajustesPermisos,
            CancellationToken cancelacion = default)
        {
            AjustesAlta = ajustesPermisos;
            SolicitudRecibida = solicitud;
            IdCarteraRecibido = idCartera;
            UsuarioRecibido = usuario;
            return Task.FromResult(new ResultadoAltaEmpleado(1, "Alta correcta."));
        }
    }

    private sealed class UsuarioActualFalso : IUsuarioActual
    {
        public bool EstaAutenticado => true;

        public int IdEmpleado => 1;

        public int IdUsuario => 1;

        public string Usuario => "ADMIN";

        public int IdCartera { get; init; } = 7;

        public string Cartera => "BAZ_FRANQUICIA";

        public IReadOnlyCollection<Perfil> Perfiles => [Perfil.Administrador];
    }
}
