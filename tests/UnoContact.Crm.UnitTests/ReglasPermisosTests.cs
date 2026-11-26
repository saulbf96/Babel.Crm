using UnoContact.Crm.Application.Acceso;
using UnoContact.Crm.Domain.Seguridad;

namespace UnoContact.Crm.UnitTests;

public sealed class ReglasPermisosTests
{
    private static readonly Perfil[] Admin = [Perfil.Administrador];
    private static readonly Perfil[] Asesor = [Perfil.Asesor];

    [Fact]
    public void Root_tiene_todo_y_los_ajustes_le_aplican()
    {
        Assert.True(ReglasPermisos.Todas.IsSubsetOf(ReglasPermisos.Efectivos([], esRoot: true, [])));

        var sinBajas = ReglasPermisos.Efectivos([], esRoot: true, [new AjustePermiso("bajas", false)]);
        Assert.DoesNotContain("bajas", sinBajas); // ROOT sí puede quitarse permisos a sí mismo
    }

    [Fact]
    public void Efectivos_son_puesto_mas_ajustes_e_inicio_siempre()
    {
        var p = ReglasPermisos.Efectivos(Asesor, false,
            [new AjustePermiso("empleados", true), new AjustePermiso("gestion-bloquear", false)]);

        Assert.Contains("inicio", p);
        Assert.Contains("gestion-nueva", p);       // del puesto
        Assert.Contains("empleados", p);           // agregado
        Assert.DoesNotContain("gestion-bloquear", p); // quitado
        Assert.DoesNotContain("bajas", p);
    }

    [Fact]
    public void Ajustes_guardan_solo_las_diferencias_contra_el_puesto()
    {
        var baseAsesor = ReglasPermisos.Base(Asesor, false);
        var deseados = baseAsesor.Where(c => c != "gestion-bloquear").Append("empleados");

        var ajustes = ReglasPermisos.Ajustes(baseAsesor, deseados);

        Assert.Equal(2, ajustes.Count);
        Assert.Contains(new AjustePermiso("empleados", true), ajustes);
        Assert.Contains(new AjustePermiso("gestion-bloquear", false), ajustes);
        Assert.Equal("empleados:1,gestion-bloquear:0", ReglasPermisos.Serializar(ajustes));
    }

    [Fact]
    public void Solo_administradores_o_root_dan_permisos()
    {
        var error = ReglasPermisos.ValidarCambio(Asesor, false, new HashSet<string> { "empleados" }, 1, 2,
            new HashSet<string>(), ["empleados"]);
        Assert.Equal("Solo un administrador puede dar o quitar permisos.", error);
    }

    [Fact]
    public void Nadie_cambia_sus_propios_permisos_salvo_root()
    {
        var mios = ReglasPermisos.Todas.ToHashSet();
        Assert.Contains("propios", ReglasPermisos.ValidarCambio(Admin, false, mios, 7, 7, mios, ["inicio"])!);
        Assert.Null(ReglasPermisos.ValidarCambio(Admin, true, mios, 7, 7, mios, ["inicio"])); // ROOT sí
    }

    [Fact]
    public void Un_admin_no_da_ni_quita_lo_que_no_tiene()
    {
        var actor = new HashSet<string> { "inicio", "empleados", "alta-empleados" };
        var actual = new HashSet<string> { "inicio" };

        Assert.Null(ReglasPermisos.ValidarCambio(Admin, false, actor, 1, 2, actual, ["empleados"]));
        var error = ReglasPermisos.ValidarCambio(Admin, false, actor, 1, 2, actual, ["empleados", "bajas"]);
        Assert.Contains("Bajas de personal", error);
    }
}
