using UnoContact.Crm.Domain.Seguridad;

namespace UnoContact.Crm.Application.Abstracciones;

/// <summary>Usuario de BABEL que inició sesión en el CRM (se lee de la cookie de sesión).</summary>
public interface IUsuarioActual
{
    bool EstaAutenticado { get; }

    int IdEmpleado { get; }

    int IdUsuario { get; }

    string Usuario { get; }

    /// <summary>Cartera activa de la sesión (la que se cambia desde "Cambia Cartera").</summary>
    int IdCartera { get; }

    string Cartera { get; }

    IReadOnlyCollection<Perfil> Perfiles { get; }

    bool TienePerfil(Perfil perfil) => Perfiles.Contains(perfil);
}
