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

    /// <summary>El usuario tiene pendiente cambiar su contraseña (lo obliga el login).</summary>
    bool DebeCambiarContrasena => false;

    /// <summary>Por qué debe cambiarla: "Forzado" o "Vencida" (null si no debe).</summary>
    string? MotivoCambioContrasena => null;

    IReadOnlyCollection<Perfil> Perfiles { get; }

    /// <summary>Opciones de menú que puede usar (claves de CatalogoMenu).</summary>
    IReadOnlyCollection<string> Permisos => [];

    /// <summary>ROOT: tiene todo y puede cambiarse sus propios permisos.</summary>
    bool EsRoot => false;

    bool TienePerfil(Perfil perfil) => Perfiles.Contains(perfil);
}
