using UnoContact.Crm.Application.Acceso;

namespace UnoContact.Crm.UnitTests;

public sealed class GeneradorContrasenaTests
{
    [Fact]
    public void Siempre_cumple_la_politica_y_no_se_repite()
    {
        var generadas = new HashSet<string>();
        for (var i = 0; i < 500; i++)
        {
            var c = GeneradorContrasena.Generar();
            Assert.Null(PoliticaContrasena.Validar(c));
            Assert.Equal(GeneradorContrasena.Largo, c.Length);
            Assert.DoesNotContain(c, ch => "Il1O0o".Contains(ch)); // sin caracteres que se confunden
            generadas.Add(c);
        }
        Assert.Equal(500, generadas.Count);
    }
}
