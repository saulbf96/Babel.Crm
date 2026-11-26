using UnoContact.Crm.Application.Acceso;
using UnoContact.Crm.Domain.Seguridad;
using Microsoft.Extensions.Options;

namespace UnoContact.Crm.UnitTests;

public sealed class ServicioAccesoTests
{
    // Datos ficticios.
    private static readonly UsuarioCrm UsuarioPrueba =
        new(IdUsuario: 1, IdEmpleado: 100, Usuario: "PRUEBA", IdPuesto: 14, IdArea: 1, Bloqueado: false, Activo: true, IdCartera: 1, Cartera: "CARTERA_PRUEBA");

    private readonly RepositorioFalso _repositorio = new();
    private readonly IntentosFalsos _intentos = new();

    private readonly RelojFijo _reloj = new(new TimeOnly(10, 0));

    private ServicioAcceso CrearServicio() => new(
        _repositorio,
        _intentos,
        Options.Create(new MapeoPerfiles { Asesor = [14], Supervisor = [17], Administrador = [1] }),
        _reloj);

    // ---------- Horario de acceso (08:00 a 14:30, 10 min de tolerancia) ----------
    private static readonly UsuarioCrm ConHorario = UsuarioPrueba with
    {
        AplicaHorario = true, HoraEntrada = new TimeOnly(8, 0), HoraSalida = new TimeOnly(14, 30),
    };

    [Theory]
    [InlineData(7, 49, false)]  // antes de la tolerancia
    [InlineData(7, 50, true)]   // 10 min antes: ya puede
    [InlineData(11, 0, true)]
    [InlineData(14, 30, true)]  // justo a la salida
    [InlineData(15, 0, false)]  // después de su horario
    public async Task Login_respeta_el_horario_con_tolerancia(int hora, int minuto, bool entra)
    {
        _repositorio.Usuario = ConHorario;
        _reloj.Hora = new TimeOnly(hora, minuto);

        var resultado = await CrearServicio().IniciarSesionAsync(Solicitud());

        Assert.Equal(entra, resultado.Exitoso);
        if (!entra) Assert.Contains("fuera de tu horario", resultado.Mensaje);
    }

    [Fact]
    public async Task Fuera_de_horario_no_cuenta_como_intento_fallido()
    {
        _repositorio.Usuario = ConHorario;
        _reloj.Hora = new TimeOnly(20, 0);
        var servicio = CrearServicio();

        for (var i = 0; i < 5; i++) await servicio.IniciarSesionAsync(Solicitud());

        Assert.False(_repositorio.Bloqueado); // la contraseña era correcta: no se bloquea
    }

    [Fact]
    public async Task No_aplica_horario_entra_a_cualquier_hora()
    {
        _repositorio.Usuario = ConHorario with { AplicaHorario = false };
        _reloj.Hora = new TimeOnly(23, 0);

        Assert.True((await CrearServicio().IniciarSesionAsync(Solicitud())).Exitoso);
    }

    [Theory]
    [InlineData(21, 50, true)]  // nocturno 22:00-06:00: tolerancia antes de medianoche
    [InlineData(3, 0, true)]
    [InlineData(6, 0, true)]
    [InlineData(6, 1, false)]
    [InlineData(12, 0, false)]
    public void Horario_nocturno_cruza_la_medianoche(int hora, int minuto, bool entra)
    {
        Assert.Equal(entra, PoliticaHorario.PuedeEntrar(new TimeOnly(hora, minuto), new TimeOnly(22, 0), new TimeOnly(6, 0)));
    }

    /// <summary>Reloj de pruebas: la hora local es la que se fija.</summary>
    private sealed class RelojFijo(TimeOnly hora) : TimeProvider
    {
        public TimeOnly Hora { get; set; } = hora;

        public override TimeZoneInfo LocalTimeZone => TimeZoneInfo.Utc;

        public override DateTimeOffset GetUtcNow() =>
            new(new DateOnly(2026, 11, 26).ToDateTime(Hora), TimeSpan.Zero);
    }

    private static SolicitudAcceso Solicitud(string usuario = "prueba", string contrasena = "secreta") =>
        new(usuario, contrasena, "10.0.0.1", "CRM-WEB");

    [Fact]
    public async Task Acceso_correcto_regresa_perfiles_segun_puesto()
    {
        _repositorio.Usuario = UsuarioPrueba;

        var resultado = await CrearServicio().IniciarSesionAsync(Solicitud());

        Assert.True(resultado.Exitoso);
        Assert.Equal([Perfil.Asesor], resultado.Perfiles);
        Assert.Equal("PRUEBA", _repositorio.UltimoUsuario); // se envía en mayúsculas, como BABEL
    }

    [Fact]
    public async Task Campos_vacios_se_rechazan_sin_consultar_la_base()
    {
        var resultado = await CrearServicio().IniciarSesionAsync(Solicitud(usuario: "  "));

        Assert.False(resultado.Exitoso);
        Assert.Null(_repositorio.UltimoUsuario);
    }

    [Fact]
    public async Task Tercer_intento_fallido_bloquea_al_usuario()
    {
        var servicio = CrearServicio();

        await servicio.IniciarSesionAsync(Solicitud());
        await servicio.IniciarSesionAsync(Solicitud());
        Assert.False(_repositorio.Bloqueado);

        var resultado = await servicio.IniciarSesionAsync(Solicitud());

        Assert.False(resultado.Exitoso);
        Assert.True(_repositorio.Bloqueado);
    }

    [Theory]
    [InlineData(true, true)]   // bloqueado
    [InlineData(false, false)] // inactivo
    public async Task Usuario_bloqueado_o_inactivo_no_entra(bool bloqueado, bool activo)
    {
        _repositorio.Usuario = UsuarioPrueba with { Bloqueado = bloqueado, Activo = activo };

        var resultado = await CrearServicio().IniciarSesionAsync(Solicitud());

        Assert.False(resultado.Exitoso);
    }

    [Fact]
    public async Task Puesto_sin_perfil_no_entra()
    {
        _repositorio.Usuario = UsuarioPrueba with { IdPuesto = 99 };

        var resultado = await CrearServicio().IniciarSesionAsync(Solicitud());

        Assert.False(resultado.Exitoso);
    }

    [Theory]
    [InlineData(MotivoCambioContrasena.Forzado)]
    [InlineData(MotivoCambioContrasena.Vencida)]
    public async Task Contrasena_forzada_o_vencida_exige_cambio_al_entrar(MotivoCambioContrasena motivo)
    {
        _repositorio.Usuario = UsuarioPrueba;
        _repositorio.Motivo = motivo;

        var resultado = await CrearServicio().IniciarSesionAsync(Solicitud());

        Assert.True(resultado.Exitoso);
        Assert.True(resultado.DebeCambiarContrasena);
        Assert.Equal(motivo, resultado.MotivoCambio);
        Assert.Equal(PoliticaContrasena.DiasVigencia, _repositorio.DiasVigenciaConsultados); // 90 días
    }

    [Fact]
    public async Task Contrasena_vigente_no_exige_cambio()
    {
        _repositorio.Usuario = UsuarioPrueba;

        var resultado = await CrearServicio().IniciarSesionAsync(Solicitud());

        Assert.False(resultado.DebeCambiarContrasena);
    }

    private sealed class RepositorioFalso : IRepositorioUsuarios
    {
        public UsuarioCrm? Usuario { get; set; }
        public string? UltimoUsuario { get; private set; }
        public bool Bloqueado { get; private set; }

        public Task<UsuarioCrm?> ValidarAsync(string usuario, string contrasena, CancellationToken cancelacion)
        {
            UltimoUsuario = usuario;
            return Task.FromResult(Usuario);
        }

        public MotivoCambioContrasena Motivo { get; set; }
        public int? DiasVigenciaConsultados { get; private set; }

        public Task<MotivoCambioContrasena> EstadoContrasenaAsync(int idUsuario, int diasVigencia, CancellationToken cancelacion)
        {
            DiasVigenciaConsultados = diasVigencia;
            return Task.FromResult(Motivo);
        }

        public Task<ReusoContrasena> RevisarReusoAsync(int idUsuario, string contrasena, int recordadas, CancellationToken cancelacion) =>
            Task.FromResult(ReusoContrasena.Ninguno);

        public List<AjustePermiso> Ajustes { get; } = [];

        public Task<IReadOnlyList<AjustePermiso>> PermisosAsync(int idUsuario, CancellationToken cancelacion) =>
            Task.FromResult<IReadOnlyList<AjustePermiso>>(Ajustes);

        public Task BloquearAsync(string usuario, string ip, string equipo, byte intentos, CancellationToken cancelacion)
        {
            Bloqueado = true;
            return Task.CompletedTask;
        }

        public Task CambiarContrasenaAsync(int idUsuario, string contrasenaNueva, CancellationToken cancelacion) =>
            Task.CompletedTask;
    }

    private sealed class IntentosFalsos : IControlIntentos
    {
        private readonly Dictionary<string, int> _fallos = [];

        public int RegistrarFallo(string usuario) => _fallos[usuario] = _fallos.GetValueOrDefault(usuario) + 1;

        public void Reiniciar(string usuario) => _fallos.Remove(usuario);
    }
}
