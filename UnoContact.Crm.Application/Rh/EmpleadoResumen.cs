namespace UnoContact.Crm.Application.Rh;

/// <summary>
/// Renglón de la pantalla "Consulta Empleados". Solo datos NO sensibles
/// (en BABEL el domicilio, sueldo y teléfonos van cifrados y no se muestran aquí).
/// </summary>
public sealed record EmpleadoResumen(
    int IdEmpleado,
    int IdCliente,
    string Cliente,
    string NombreCompleto,
    byte IdPuesto,
    string Puesto,
    byte IdDepartamento,
    string Departamento,
    string? Rfc,
    string? Email,
    DateOnly FechaIngreso,
    bool Activo);

/// <summary>Filtros de búsqueda de empleados (equivale a @IDBASE, @NOMBRE, @ID_PUESTO de BABEL).</summary>
public sealed record FiltroEmpleados(
    int? IdCliente = null,
    string? Nombre = null,
    byte? IdPuesto = null,
    bool SoloActivos = true);
