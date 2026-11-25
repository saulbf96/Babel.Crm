using System.ComponentModel.DataAnnotations;

namespace UnoContact.Crm.Application.Rh;

/// <summary>
/// Datos del alta de empleado (equivale a INSERTA_NEEU_EMPLEADOS_MODULO).
/// La cartera no se captura: se toma de la sesión activa, igual que el .exe.
/// </summary>
public sealed record SolicitudAltaEmpleado(
    [Range(1, 255, ErrorMessage = "Selecciona un puesto.")]
    byte IdPuesto,
    [Range(1, 255, ErrorMessage = "Selecciona un sexo.")]
    byte IdSexo,
    [Range(1, 255, ErrorMessage = "Selecciona un turno.")]
    byte IdTurno,
    [Required(ErrorMessage = "Ingresa el nombre del empleado.")]
    [StringLength(100, ErrorMessage = "El nombre no puede pasar de 100 caracteres.")]
    string Nombre,
    [Required(ErrorMessage = "Ingresa el apellido paterno.")]
    [StringLength(100, ErrorMessage = "El apellido paterno no puede pasar de 100 caracteres.")]
    string Paterno,
    [Required(ErrorMessage = "Ingresa el apellido materno.")]
    [StringLength(100, ErrorMessage = "El apellido materno no puede pasar de 100 caracteres.")]
    string Materno);

public sealed record ResultadoAltaEmpleado(int IdEmpleado, string Mensaje);
