using UnoContact.Crm.Application.Sesion;
using UnoContact.Crm.Domain.Seguridad;

namespace UnoContact.Crm.UnitTests;

public sealed class CatalogoMenuTests
{
    [Fact]
    public void Asesor_no_ve_administracion()
    {
        var claves = CatalogoMenu.ParaPerfiles([Perfil.Asesor]).Select(o => o.Clave).ToList();

        Assert.Contains("inicio", claves);
        Assert.Contains("asesor", claves);
        Assert.DoesNotContain("administracion", claves);
    }

    [Fact]
    public void Sin_perfiles_no_hay_menu()
    {
        Assert.Empty(CatalogoMenu.ParaPerfiles([]));
    }
}
