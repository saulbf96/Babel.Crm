using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Mvc.Testing;

namespace UnoContact.Crm.IntegrationTests;

/// <summary>Pruebas de seguridad de la API que no necesitan base de datos.</summary>
public sealed class SeguridadApiTests(WebApplicationFactory<Program> fabrica) : IClassFixture<WebApplicationFactory<Program>>
{
    private HttpClient Cliente() => fabrica.CreateClient(new WebApplicationFactoryClientOptions
    {
        BaseAddress = new Uri("https://localhost"),
        AllowAutoRedirect = false,
    });

    [Fact]
    public async Task Salud_responde_sin_sesion()
    {
        var respuesta = await Cliente().GetAsync("/api/salud");

        Assert.Equal(HttpStatusCode.OK, respuesta.StatusCode);
    }

    [Fact]
    public async Task Sesion_sin_cookie_responde_401()
    {
        var respuesta = await Cliente().GetAsync("/api/sesion");

        Assert.Equal(HttpStatusCode.Unauthorized, respuesta.StatusCode);
    }

    [Fact]
    public async Task Post_sin_encabezado_anti_csrf_se_rechaza()
    {
        var respuesta = await Cliente().PostAsJsonAsync("/api/acceso/iniciar", new { usuario = "PRUEBA", contrasena = "x" });

        Assert.Equal(HttpStatusCode.BadRequest, respuesta.StatusCode);
    }

    [Fact]
    public async Task Respuestas_traen_encabezados_de_seguridad()
    {
        var respuesta = await Cliente().GetAsync("/api/salud");

        Assert.Equal("nosniff", respuesta.Headers.GetValues("X-Content-Type-Options").Single());
        Assert.Equal("DENY", respuesta.Headers.GetValues("X-Frame-Options").Single());
    }
}
