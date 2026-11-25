using UnoContact.Crm.Domain.Seguridad;

namespace UnoContact.Crm.Application.Acceso;

/// <summary>
/// Puestos de BABEL (columna "ID PUESTO") que otorgan cada perfil del CRM.
/// Se configura en "Seguridad:PuestosPorPerfil". La tabla definitiva está "Por confirmar con usuarios".
/// </summary>
public sealed class MapeoPerfiles
{
    public const string Seccion = "Seguridad:PuestosPorPerfil";

    public List<short> Asesor { get; set; } = [];
    public List<short> Supervisor { get; set; } = [];
    public List<short> Administrador { get; set; } = [];

    public IReadOnlyCollection<Perfil> PerfilesDe(short idPuesto)
    {
        var perfiles = new List<Perfil>();
        if (Asesor.Contains(idPuesto)) perfiles.Add(Perfil.Asesor);
        if (Supervisor.Contains(idPuesto)) perfiles.Add(Perfil.Supervisor);
        if (Administrador.Contains(idPuesto)) perfiles.Add(Perfil.Administrador);
        return perfiles;
    }
}
