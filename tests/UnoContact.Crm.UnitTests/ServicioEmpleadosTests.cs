using UnoContact.Crm.Application.Abstracciones;
using UnoContact.Crm.Application.Rh;
using UnoContact.Crm.Domain.Seguridad;

namespace UnoContact.Crm.UnitTests;

/// <summary>
/// Verifica la paridad del Alta con el .exe: la cartera sale de la sesión y el materno es obligatorio.
/// </summary>
public sealed class ServicioEmpleadosTests
{
    [Fact]
    public async Task Alta_usa_la_cartera_de_la_sesion_y_normaliza_nombres()
    {
        var repositorio = new RepositorioEmpleadosFalso();
        var servicio = new ServicioEmpleados(repositorio, new UsuarioActualFalso { IdCartera = 7 });

        var resultado = await servicio.AltaAsync(
            new SolicitudAltaEmpleado(14, 1, 1, "  PRUEBA  ", "  FLUJO  ", "  LOPEZ  "));

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
            new SolicitudAltaEmpleado(14, 1, 1, "PRUEBA", "FLUJO", "   ")));

        Assert.Null(repositorio.SolicitudRecibida);
    }

    private sealed class RepositorioEmpleadosFalso : IRepositorioEmpleados
    {
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
            CancellationToken cancelacion = default)
        {
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
