using UnoContact.Crm.Application.Acceso;
using UnoContact.Crm.Domain.Seguridad;
using Microsoft.Extensions.Options;

namespace UnoContact.Crm.UnitTests;

public sealed class ServicioAccesoTests
{
    // Datos ficticios.
    private static readonly UsuarioCrm UsuarioPrueba =
        new(IdEmpleado: 100, Usuario: "PRUEBA", IdPuesto: 14, IdArea: 1, Bloqueado: false, Activo: true, IdBaseDatos: 1, BaseDatos: "BASE_PRUEBA");

    private readonly RepositorioFalso _repositorio = new();
    private readonly IntentosFalsos _intentos = new();

    private ServicioAcceso CrearServicio() => new(
        _repositorio,
        _intentos,
        Options.Create(new MapeoPerfiles { Asesor = [14], Supervisor = [17], Administrador = [1] }));

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

        public Task<bool> DebeCambiarContrasenaAsync(int idEmpleado, CancellationToken cancelacion) => Task.FromResult(false);

        public Task BloquearAsync(string usuario, string ip, string equipo, byte intentos, CancellationToken cancelacion)
        {
            Bloqueado = true;
            return Task.CompletedTask;
        }
    }

    private sealed class IntentosFalsos : IControlIntentos
    {
        private readonly Dictionary<string, int> _fallos = [];

        public int RegistrarFallo(string usuario) => _fallos[usuario] = _fallos.GetValueOrDefault(usuario) + 1;

        public void Reiniciar(string usuario) => _fallos.Remove(usuario);
    }
}
