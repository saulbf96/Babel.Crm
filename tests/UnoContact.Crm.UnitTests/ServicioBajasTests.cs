using UnoContact.Crm.Application.Abstracciones;
using UnoContact.Crm.Application.Rh;
using UnoContact.Crm.Domain.Seguridad;

namespace UnoContact.Crm.UnitTests;

public sealed class ServicioBajasTests
{
    private const string ComentarioValido = "Abandono de trabajo, 3 faltas seguidas.";

    private readonly RepositorioFalso _repositorio = new();
    private readonly UsuarioFalso _usuario = new();

    private ServicioBajas CrearServicio() => new(_repositorio, _usuario);

    [Fact]
    public async Task Baja_valida_usa_la_cartera_y_el_usuario_de_la_sesion()
    {
        var resultado = await CrearServicio().DarDeBajaAsync(10, new SolicitudBaja(1, "  " + ComentarioValido + "  ", null));

        Assert.Equal(25, resultado.CuentasAsignadas);
        Assert.Equal((byte)7, _repositorio.Cartera);
        Assert.Equal("ADMIN", _repositorio.Usuario);
        Assert.Equal(99, _repositorio.IdUsuarioActual);
        Assert.Equal(ComentarioValido, _repositorio.Comentario); // recortado
        Assert.Equal(DateOnly.FromDateTime(DateTime.Today), _repositorio.Fecha); // sin fecha = hoy
    }

    [Fact]
    public async Task Baja_sin_causa_se_rechaza()
    {
        await Assert.ThrowsAsync<ArgumentException>(() =>
            CrearServicio().DarDeBajaAsync(10, new SolicitudBaja(0, ComentarioValido, null)));
        Assert.Null(_repositorio.Cartera);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("corto")]
    public async Task Baja_sin_comentario_suficiente_se_rechaza(string? comentario)
    {
        await Assert.ThrowsAsync<ArgumentException>(() =>
            CrearServicio().DarDeBajaAsync(10, new SolicitudBaja(1, comentario, null)));
        Assert.Null(_repositorio.Cartera);
    }

    [Theory]
    [InlineData(1)]     // mañana
    [InlineData(-1)]    // ayer
    [InlineData(-365)]  // hace un año
    public async Task La_baja_siempre_es_con_fecha_de_hoy(int dias)
    {
        var otraFecha = DateOnly.FromDateTime(DateTime.Today.AddDays(dias));

        await CrearServicio().DarDeBajaAsync(10, new SolicitudBaja(1, ComentarioValido, otraFecha));

        Assert.Equal(DateOnly.FromDateTime(DateTime.Today), _repositorio.Fecha);
    }

    [Fact]
    public async Task Reactivar_exige_comentario()
    {
        await Assert.ThrowsAsync<ArgumentException>(() =>
            CrearServicio().ReactivarAsync(10, new SolicitudReactivacion("ok")));

        await CrearServicio().ReactivarAsync(10, new SolicitudReactivacion("Reingreso autorizado por RH."));
        Assert.Equal((byte)7, _repositorio.Cartera);
    }

    [Fact]
    public async Task Sin_cartera_activa_no_se_consulta()
    {
        _usuario.IdCartera = 0;

        await Assert.ThrowsAsync<InvalidOperationException>(() => CrearServicio().ConsultarAsync(null, EstatusBaja.Activos));
    }

    private sealed class UsuarioFalso : IUsuarioActual
    {
        public bool EstaAutenticado => true;
        public int IdEmpleado => 0;
        public int IdUsuario => 99;
        public string Usuario => "ADMIN";
        public int IdCartera { get; set; } = 7;
        public string Cartera => "CARTERA_PRUEBA";
        public IReadOnlyCollection<Perfil> Perfiles => [Perfil.Administrador];
    }

    private sealed class RepositorioFalso : IRepositorioBajas
    {
        public byte? Cartera { get; private set; }
        public string? Usuario { get; private set; }
        public int IdUsuarioActual { get; private set; }
        public string? Comentario { get; private set; }
        public DateOnly? Fecha { get; private set; }

        public Task<IReadOnlyList<CausaBaja>> CausasAsync(CancellationToken cancelacion) =>
            Task.FromResult<IReadOnlyList<CausaBaja>>([new CausaBaja(1, "FALTAS")]);

        public Task<IReadOnlyList<EmpleadoBaja>> ConsultarAsync(byte idCartera, string? nombre, EstatusBaja estatus, CancellationToken cancelacion)
        {
            Cartera = idCartera;
            return Task.FromResult<IReadOnlyList<EmpleadoBaja>>([]);
        }

        public Task<ResultadoBaja> DarDeBajaAsync(
            int idEmpleado, byte idCartera, byte idCausaBaja, string comentario, DateOnly fechaBaja,
            int idUsuarioActual, string usuario, CancellationToken cancelacion)
        {
            Cartera = idCartera;
            Usuario = usuario;
            IdUsuarioActual = idUsuarioActual;
            Comentario = comentario;
            Fecha = fechaBaja;
            return Task.FromResult(new ResultadoBaja(25, 1));
        }

        public Task ReactivarAsync(int idEmpleado, byte idCartera, string comentario, string usuario, CancellationToken cancelacion)
        {
            Cartera = idCartera;
            return Task.CompletedTask;
        }
    }
}
