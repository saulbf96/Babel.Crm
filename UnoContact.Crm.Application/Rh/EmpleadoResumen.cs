namespace UnoContact.Crm.Application.Rh;

/// <summary>
/// Renglón de la pantalla "Consulta Empleados" (paridad con FRM_CONSULTAEMPLEADOS).
/// Solo datos NO sensibles: no se incluyen domicilio, sueldo ni teléfonos cifrados.
/// </summary>
public sealed record EmpleadoResumen(
    int IdEmpleado,
    string NombreCompleto,
    string? Usuario,
    byte IdPuesto,
    string Puesto,
    byte IdDepartamento,
    string Departamento,
    byte? IdCartera,
    string? Cartera,
    byte IdSexo,
    string Sexo,
    byte IdTurno,
    string Turno,
    DateOnly? FechaNacimiento,
    DateOnly FechaIngreso,
    string? Rfc,
    string? Curp,
    long? Nss,
    string? Email,
    bool Activo,
    DateTime FechaRegistro);

/// <summary>Filtros de búsqueda de empleados (equivale a @IDBASE, @NOMBRE, @ID_PUESTO de BABEL).</summary>
public sealed record FiltroEmpleados(
    byte? IdCartera = null,
    string? Nombre = null,
    byte? IdPuesto = null,
    bool SoloActivos = true);
