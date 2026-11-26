using UnoContact.Crm.Application.Rh;

namespace UnoContact.Crm.UnitTests;

public sealed class ReglasUsuarioTests
{
    [Theory]
    [InlineData("MARÍA JOSÉ", "LÓPEZ", "MLOPEZ")]
    [InlineData("ANGEL ESTEBAN", "AGUILAR", "AAGUILAR")]
    [InlineData("ÑOÑO", "MUÑOZ", "NMUNOZ")]
    [InlineData("JUAN", "DE LA CRUZ", "JDELACRUZ")]
    [InlineData("ANA", "AGÜERO", "AAGUERO")]
    public void Usuario_base_es_inicial_mas_apellido_sin_acentos_ni_espacios(string nombre, string paterno, string esperado)
    {
        Assert.Equal(esperado, ReglasUsuario.Base(nombre, paterno));
    }
}
