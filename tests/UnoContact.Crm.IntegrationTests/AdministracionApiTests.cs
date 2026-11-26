using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;

namespace UnoContact.Crm.IntegrationTests;

/// <summary>
/// Prueba de humo del módulo Administrador contra BABEL_UNIFICADA.
/// Solo lee información y reemite la cookie con la misma cartera: no crea ni modifica datos.
/// Requiere la base local y el usuario ADMIN de pruebas.
/// </summary>
[Trait("Categoria", "BaseDatos")]
public sealed class AdministracionApiTests : IClassFixture<AdministracionApiTests.Fabrica>
{
    private const string Usuario = "ADMIN";
    private const string Contrasena = "Babel2026!";

    private readonly Fabrica _fabrica;

    public AdministracionApiTests(Fabrica fabrica) => _fabrica = fabrica;

    public sealed class Fabrica : WebApplicationFactory<Program>
    {
        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            // La fábrica de pruebas no carga los secretos del servidor por sí sola.
            builder.ConfigureAppConfiguration((_, configuracion) =>
                configuracion.AddUserSecrets<Program>());
        }
    }

    private HttpClient Cliente()
    {
        var cliente = _fabrica.CreateClient(new WebApplicationFactoryClientOptions
        {
            BaseAddress = new Uri("https://localhost"),
            AllowAutoRedirect = false,
        });
        cliente.DefaultRequestHeaders.Add("X-UnoContact-Crm", "1");
        return cliente;
    }

    [Fact]
    public async Task Flujo_de_administracion_responde_con_datos_reales()
    {
        using var cliente = Cliente();

        var acceso = await cliente.PostAsJsonAsync(
            "/api/acceso/iniciar",
            new { usuario = Usuario, contrasena = Contrasena });
        Assert.Equal(HttpStatusCode.OK, acceso.StatusCode);

        var sesion = await LeerJsonAsync(cliente, "/api/sesion");
        Assert.Equal(Usuario, sesion.RootElement.GetProperty("usuario").GetString());
        Assert.Contains(
            "Administrador",
            sesion.RootElement.GetProperty("perfiles").EnumerateArray().Select(p => p.GetString()));
        var idCartera = sesion.RootElement.GetProperty("idCartera").GetInt32();
        Assert.True(idCartera > 0);

        var catalogos = await LeerJsonAsync(cliente, "/api/catalogos");
        Assert.Equal(13, catalogos.RootElement.GetProperty("carteras").GetArrayLength());
        Assert.NotEqual(0, catalogos.RootElement.GetProperty("puestos").GetArrayLength());
        Assert.Equal(3, catalogos.RootElement.GetProperty("sexos").GetArrayLength());
        Assert.NotEqual(0, catalogos.RootElement.GetProperty("turnos").GetArrayLength());

        var carteras = await LeerJsonAsync(cliente, "/api/carteras");
        Assert.NotEqual(0, carteras.RootElement.GetArrayLength());

        var personal = await LeerJsonAsync(cliente, $"/api/carteras/{idCartera}/personal");
        Assert.Equal(JsonValueKind.Array, personal.RootElement.ValueKind);

        var operativo = await LeerJsonAsync(cliente, $"/api/carteras/operativo?idCartera={idCartera}");
        Assert.Equal(JsonValueKind.Array, operativo.RootElement.ValueKind);

        var procesos = await LeerJsonAsync(cliente, "/api/cargas/procesos");
        Assert.Equal(4, procesos.RootElement.GetArrayLength());

        var cargas = await LeerJsonAsync(cliente, $"/api/cargas?idCartera={idCartera}");
        Assert.Equal(JsonValueKind.Array, cargas.RootElement.ValueKind);

        // Reemite la cookie con la misma cartera; no cambia datos de negocio.
        var cambio = await cliente.PostAsJsonAsync("/api/sesion/cartera", new { idCartera });
        Assert.Equal(HttpStatusCode.OK, cambio.StatusCode);
        var cambioJson = await cambio.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(idCartera, cambioJson.GetProperty("idCartera").GetInt32());

        // Validaciones: no deben crear nada y deben responder 400, no 500.
        var altaInvalida = await cliente.PostAsJsonAsync("/api/empleados", new { });
        var altaCuerpo = await altaInvalida.Content.ReadAsStringAsync();
        Assert.True(
            altaInvalida.StatusCode == HttpStatusCode.BadRequest,
            $"Alta inválida: {(int)altaInvalida.StatusCode} {altaCuerpo}");

        // El alta ya no recibe cartera (usa la de la sesión) y exige apellido materno.
        var altaSinMaterno = await cliente.PostAsJsonAsync("/api/empleados", new
        {
            idPuesto = 1,
            idSexo = 1,
            horaEntrada = "09:00:00",
            horaSalida = "18:00:00",
            nombre = "PRUEBA",
            paterno = "FLUJO",
        });
        var altaSinMaternoCuerpo = await altaSinMaterno.Content.ReadAsStringAsync();
        Assert.True(
            altaSinMaterno.StatusCode == HttpStatusCode.BadRequest,
            $"Alta sin materno: {(int)altaSinMaterno.StatusCode} {altaSinMaternoCuerpo}");

        var restauracionVacia = await cliente.PostAsJsonAsync(
            "/api/carteras/restaurar",
            new { idsEmpleados = Array.Empty<int>() });
        var restauracionCuerpo = await restauracionVacia.Content.ReadAsStringAsync();
        Assert.True(
            restauracionVacia.StatusCode == HttpStatusCode.BadRequest,
            $"Restauración vacía: {(int)restauracionVacia.StatusCode} {restauracionCuerpo}");

        var cargaVacia = await cliente.PostAsJsonAsync("/api/cargas", new { });
        var cargaCuerpo = await cargaVacia.Content.ReadAsStringAsync();
        Assert.True(
            cargaVacia.StatusCode == HttpStatusCode.BadRequest,
            $"Carga vacía: {(int)cargaVacia.StatusCode} {cargaCuerpo}");
    }

    private static async Task<JsonDocument> LeerJsonAsync(HttpClient cliente, string ruta)
    {
        var respuesta = await cliente.GetAsync(ruta);
        Assert.Equal(HttpStatusCode.OK, respuesta.StatusCode);
        return JsonDocument.Parse(await respuesta.Content.ReadAsStringAsync());
    }
}
