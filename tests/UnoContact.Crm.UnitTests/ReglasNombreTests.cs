using UnoContact.Crm.Application.Rh;

namespace UnoContact.Crm.UnitTests;

public sealed class ReglasNombreTests
{
    [Theory]
    [InlineData("maría josé", "MARÍA JOSÉ")]        // espacios entre palabras + acentos + mayúsculas
    [InlineData("  de   la  cruz ", "DE LA CRUZ")]  // espacios dobles y en los extremos
    [InlineData("Muñoz", "MUÑOZ")]
    [InlineData("Agüero", "AGÜERO")]
    public void Nombres_validos_se_normalizan(string entrada, string esperado)
    {
        Assert.Equal(esperado, ReglasNombre.Validar(entrada, "nombre"));
    }

    [Theory]
    [InlineData("JUAN2")]     // números
    [InlineData("JUAN.")]     // símbolos
    [InlineData("O'BRIEN")]
    [InlineData("PEREZ-LOPEZ")]
    [InlineData("ANA@")]
    [InlineData("   ")]       // vacío
    public void Nombres_invalidos_se_rechazan(string entrada)
    {
        Assert.Throws<ArgumentException>(() => ReglasNombre.Validar(entrada, "nombre"));
    }
}
