namespace Babel.Crm.Domain.Seguridad;

/// <summary>
/// Puestos que usan los aplicativos de escritorio (catálogo de RH, columna "ID PUESTO").
/// Se conservan para la convivencia con BABEL sobre la misma base de datos.
/// La equivalencia puesto → perfil está "Por confirmar con usuarios".
/// </summary>
public enum PuestoBabel : short
{
    DirectorGeneral = 1,
    GerenteOperacion = 5,
    Administrativo = 8,
    EjecutivoTelefonico = 14,
    CoordinadorCartera = 16,
    SupervisorCartera = 17,
    CoordinadorCalidad = 23,
    CoordinadorVisitas = 24,
    DirectorOperacion = 26,
    ProjectManager = 27,
    MonitorCalidad = 28
}
