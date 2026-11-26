using System.Text.RegularExpressions;

namespace UnoContact.Crm.Application.Rh;

/// <summary>
/// Reglas para nombre y apellidos (BABEL no validaba nada: aceptaba números y símbolos).
///  - Solo letras (incluye Á É Í Ó Ú Ü Ñ) y espacios entre palabras ("MARÍA JOSÉ", "DE LA CRUZ").
///  - Se quitan espacios al inicio/fin y los dobles; se guarda en MAYÚSCULAS como el resto de los datos.
/// La pantalla valida lo mismo mientras se escribe; aquí se vuelve a validar (no se confía en el front).
/// </summary>
public static partial class ReglasNombre
{
    [GeneratedRegex(@"^[A-ZÁÉÍÓÚÜÑ]+( [A-ZÁÉÍÓÚÜÑ]+)*$")]
    private static partial Regex SoloLetras();

    [GeneratedRegex(@"\s+")]
    private static partial Regex Espacios();

    /// <summary>Quita espacios sobrantes y pasa a mayúsculas.</summary>
    public static string Normalizar(string? valor) =>
        Espacios().Replace((valor ?? string.Empty).Trim(), " ").ToUpperInvariant();

    /// <summary>Normaliza y valida. Lanza ArgumentException con el mensaje para el usuario.</summary>
    public static string Validar(string? valor, string campo)
    {
        var limpio = Normalizar(valor);
        if (limpio.Length == 0)
            throw new ArgumentException($"Ingresa el {campo}.");
        if (limpio.Length > 100)
            throw new ArgumentException($"El {campo} no puede pasar de 100 caracteres.");
        if (!SoloLetras().IsMatch(limpio))
            throw new ArgumentException($"El {campo} solo puede llevar letras y espacios (sin números ni símbolos).");
        return limpio;
    }
}
