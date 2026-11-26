using UnoContact.Crm.Application.Sesion;
using UnoContact.Crm.Domain.Seguridad;

namespace UnoContact.Crm.UnitTests;

public sealed class CatalogoMenuTests
{
    [Fact]
    public void Asesor_no_ve_administracion()
    {
        var opciones = CatalogoMenu.ParaPerfiles([Perfil.Asesor]);
        var claves = opciones.Select(o => o.Clave).ToList();

        Assert.Contains("inicio", claves);
        Assert.Contains("gestion-nueva", claves);
        // El Asesor no ve ninguna opción del área de Administración.
        Assert.DoesNotContain(opciones, o => o.Grupo == "Administración");
    }

    [Fact]
    public void Sin_perfiles_no_hay_menu()
    {
        Assert.Empty(CatalogoMenu.ParaPerfiles([]));
    }
}
