namespace UnoContact.Crm.Application.Acceso;

/// <summary>
/// Horario de acceso (NUEVO: BABEL no lo tenía). Reglas del usuario (26/11/2026):
///  - Horario por defecto 08:00 a 14:30 (el admin lo cambia en Consulta de empleados > Editar).
///  - Puede entrar desde <see cref="ToleranciaEntradaMinutos"/> minutos antes de su hora de entrada.
///  - La sesión abierta NO se corta al terminar el horario (solo por inactividad); si la cierra
///    fuera de horario, ya no puede volver a entrar.
///  - Aplica a todos, salvo a quien el admin marque "No aplica horario" o no tenga horas.
///  - El horario puede cruzar la medianoche (ej. 22:00 a 06:00).
/// </summary>
public static class PoliticaHorario
{
    public const int ToleranciaEntradaMinutos = 10;

    public static readonly TimeOnly EntradaPorDefecto = new(8, 0);
    public static readonly TimeOnly SalidaPorDefecto = new(14, 30);

    /// <summary>¿Puede iniciar sesión a esta hora?</summary>
    public static bool PuedeEntrar(TimeOnly ahora, TimeOnly entrada, TimeOnly salida)
    {
        var desde = entrada.AddMinutes(-ToleranciaEntradaMinutos);
        // La resta de TimeOnly da el tiempo "hacia adelante" (da la vuelta a la medianoche),
        // así que sirve igual para 08:00-14:30 que para 22:00-06:00.
        return (ahora - desde) <= (salida - desde);
    }

    /// <summary>Hora desde la que puede entrar (entrada menos la tolerancia).</summary>
    public static TimeOnly DesdeCuandoPuedeEntrar(TimeOnly entrada) => entrada.AddMinutes(-ToleranciaEntradaMinutos);
}
