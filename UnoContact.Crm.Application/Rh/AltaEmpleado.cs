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
    // El turno (matutino/vespertino) se reemplazó por el horario real (26/11/2026).
    // Sin las dos horas => no aplica horario.
    TimeOnly? HoraEntrada,
    TimeOnly? HoraSalida,
    [Required(ErrorMessage = "Ingresa el nombre del empleado.")]
    [StringLength(100, ErrorMessage = "El nombre no puede pasar de 100 caracteres.")]
    string Nombre,
    [Required(ErrorMessage = "Ingresa el apellido paterno.")]
    [StringLength(100, ErrorMessage = "El apellido paterno no puede pasar de 100 caracteres.")]
    string Paterno,
    [Required(ErrorMessage = "Ingresa el apellido materno.")]
    [StringLength(100, ErrorMessage = "El apellido materno no puede pasar de 100 caracteres.")]
    string Materno,
    // true = el admin revisó las coincidencias y confirma que es OTRA persona con el mismo nombre.
    bool ConfirmarHomonimo = false,
    // false = "No aplica horario": puede entrar a cualquier hora.
    bool AplicaHorario = true,
    // Permisos que tendrá (claves de menú). null = solo lo de su puesto.
    IReadOnlyList<string>? Permisos = null,
    // Multi-campaña: campañas a las que pertenece (1 o más). null = la cartera de la sesión.
    IReadOnlyList<byte>? Carteras = null,
    // Con la que entra al iniciar sesión; debe estar en Carteras. null = la de la sesión o la primera.
    byte? CarteraPrincipal = null);

/// <summary>Permisos actuales de un empleado (sección Permisos de Editar).</summary>
public sealed record PermisosEmpleado(
    bool TieneUsuario,
    bool EsRoot,
    // true = es el mismo usuario que está editando (solo ROOT puede cambiarse sus permisos).
    bool EsUstedMismo,
    bool PuedeEditar,
    string? Motivo,
    IReadOnlyList<string> Permisos);

/// <summary>Renglón del historial de altas (rh.USP_CONSULTA_ALTAS, fuente: bitácora).</summary>
public sealed record AltaRegistrada(
    DateTime FechaAlta,
    string RegistradoPor,
    string NombreCompleto,
    string? Usuario,
    string Puesto,
    TimeOnly? HoraEntrada,
    TimeOnly? HoraSalida,
    bool AplicaHorario,
    bool Activo);

/// <summary>Edición de empleado (NUEVO: BABEL nunca tuvo pantalla para editar).</summary>
public sealed record SolicitudEdicionEmpleado(
    [Required(ErrorMessage = "Ingresa el nombre del empleado.")]
    [StringLength(100, ErrorMessage = "El nombre no puede pasar de 100 caracteres.")]
    string Nombre,
    [Required(ErrorMessage = "Ingresa el apellido paterno.")]
    [StringLength(100, ErrorMessage = "El apellido paterno no puede pasar de 100 caracteres.")]
    string Paterno,
    [Required(ErrorMessage = "Ingresa el apellido materno.")]
    [StringLength(100, ErrorMessage = "El apellido materno no puede pasar de 100 caracteres.")]
    string Materno,
    [Range(1, 255, ErrorMessage = "Selecciona un puesto.")]
    byte IdPuesto,
    [Range(1, 255, ErrorMessage = "Selecciona un sexo.")]
    byte IdSexo,
    TimeOnly? HoraEntrada,
    TimeOnly? HoraSalida,
    bool AplicaHorario = true,
    // Permisos que quedarán. null = no se cambian.
    IReadOnlyList<string>? Permisos = null);

/// <summary>
/// Resultado del alta. Si <see cref="Coincidencias"/> trae renglones, NO se dio de alta:
/// la persona ya existe y la pantalla ofrece moverla, darle acceso o reactivarla.
/// </summary>
public sealed record ResultadoAltaEmpleado(
    int IdEmpleado,
    string Mensaje,
    IReadOnlyList<EmpleadoCoincidente>? Coincidencias = null,
    // Usuario del sistema que se le creó (cambio de contraseña obligatorio al primer acceso).
    string? Usuario = null,
    // Contraseña temporal ÚNICA: se muestra una sola vez al administrador.
    string? ContrasenaTemporal = null);

/// <summary>Empleado ya registrado con el mismo nombre completo (rh.USP_BUSCA_DUPLICADOS).</summary>
public sealed record EmpleadoCoincidente(
    int IdEmpleado,
    string NombreCompleto,
    string Puesto,
    bool Activo,
    DateOnly FechaIngreso,
    string? CarteraActiva,
    bool EnEstaCartera,
    bool TieneAcceso,
    string? Usuario);
