using UnoContact.Crm.Application.Acceso;

namespace UnoContact.Crm.UnitTests;

public sealed class ServicioCambioContrasenaTests
{
    private const string Valida = "Nueva#2026x";

    private readonly RepositorioFalso _repositorio = new();

    private ServicioCambioContrasena CrearServicio() => new(_repositorio);

    [Fact]
    public async Task Contrasena_valida_y_nueva_se_guarda()
    {
        var error = await CrearServicio().CambiarAsync(1, Valida);

        Assert.Null(error);
        Assert.Equal(Valida, _repositorio.Guardada);
        Assert.Equal(PoliticaContrasena.ContrasenasRecordadas, _repositorio.RecordadasConsultadas);
    }

    [Fact]
    public async Task Igual_a_la_actual_se_rechaza_y_no_se_guarda()
    {
        _repositorio.Reuso = ReusoContrasena.Actual;

        var error = await CrearServicio().CambiarAsync(1, Valida);

        Assert.Equal(ServicioCambioContrasena.MensajeIgualActual, error);
        Assert.Null(_repositorio.Guardada);
    }

    [Fact]
    public async Task Igual_a_una_anterior_se_rechaza_y_no_se_guarda()
    {
        _repositorio.Reuso = ReusoContrasena.Anterior;

        var error = await CrearServicio().CambiarAsync(1, Valida);

        Assert.Equal(ServicioCambioContrasena.MensajeIgualAnterior, error);
        Assert.Null(_repositorio.Guardada);
    }

    [Theory]
    [InlineData("corta1!")]          // menos de 8
    [InlineData("sinmayuscula1!")]   // sin mayúscula
    [InlineData("SINMINUSCULA1!")]   // sin minúscula
    [InlineData("SinNumero!!")]      // sin número
    [InlineData("SinEspecial123")]   // sin especial
    public async Task Regla_de_composicion_se_valida_antes_de_consultar_historial(string contrasena)
    {
        var error = await CrearServicio().CambiarAsync(1, contrasena);

        Assert.NotNull(error);
        Assert.Null(_repositorio.RecordadasConsultadas); // ni siquiera consulta la base
        Assert.Null(_repositorio.Guardada);
    }

    private sealed class RepositorioFalso : IRepositorioUsuarios
    {
        public ReusoContrasena Reuso { get; set; }
        public int? RecordadasConsultadas { get; private set; }
        public string? Guardada { get; private set; }

        public Task<ReusoContrasena> RevisarReusoAsync(int idUsuario, string contrasena, int recordadas, CancellationToken cancelacion)
        {
            RecordadasConsultadas = recordadas;
            return Task.FromResult(Reuso);
        }

        public Task CambiarContrasenaAsync(int idUsuario, string contrasenaNueva, CancellationToken cancelacion)
        {
            Guardada = contrasenaNueva;
            return Task.CompletedTask;
        }

        public Task<UsuarioCrm?> ValidarAsync(string usuario, string contrasena, CancellationToken cancelacion) =>
            Task.FromResult<UsuarioCrm?>(null);

        public Task<MotivoCambioContrasena> EstadoContrasenaAsync(int idUsuario, int diasVigencia, CancellationToken cancelacion) =>
            Task.FromResult(MotivoCambioContrasena.Ninguno);

        public List<AjustePermiso> Ajustes { get; } = [];

        public Task<IReadOnlyList<AjustePermiso>> PermisosAsync(int idUsuario, CancellationToken cancelacion) =>
            Task.FromResult<IReadOnlyList<AjustePermiso>>(Ajustes);

        public Task BloquearAsync(string usuario, string ip, string equipo, byte intentos, CancellationToken cancelacion) =>
            Task.CompletedTask;
    }
}
