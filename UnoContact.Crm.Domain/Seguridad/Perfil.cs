namespace UnoContact.Crm.Domain.Seguridad;

/// <summary>
/// Perfiles del CRM unificado. Sustituyen el control por puesto de los aplicativos
/// de escritorio (BABEL GESTION para asesores y BABEL ADMINISTRATIVO para back office).
/// </summary>
public enum Perfil
{
    Asesor = 1,
    Supervisor = 2,
    Administrador = 3
}
