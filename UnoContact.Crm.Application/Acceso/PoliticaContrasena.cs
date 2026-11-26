namespace UnoContact.Crm.Application.Acceso;

/// <summary>
/// Regla de contraseña del CRM (BABEL no exigía ninguna; aquí se endurece).
/// Mínimo 8, máximo 30 (como el .exe), con mayúscula, minúscula, número y un carácter especial.
/// Se valida SIEMPRE en el servidor; el front solo la refleja para avisar antes.
/// </summary>
public static class PoliticaContrasena
{
    public const int LongitudMinima = 8;
    public const int LongitudMaxima = 30;

    /// <summary>Contraseñas anteriores que no se pueden reutilizar (además de la actual). PCI DSS pide 4.</summary>
    public const int ContrasenasRecordadas = 5;

    /// <summary>Días que dura una contraseña; al vencer, el login exige cambiarla.</summary>
    public const int DiasVigencia = 90;

    public const string Descripcion =
        "Mínimo 8 caracteres, con mayúscula, minúscula, número y un carácter especial.";

    /// <summary>Regresa null si la contraseña cumple, o el mensaje de error si no.</summary>
    public static string? Validar(string? contrasena)
    {
        var c = contrasena ?? string.Empty;

        if (c.Length < LongitudMinima)
            return $"La contraseña debe tener al menos {LongitudMinima} caracteres.";
        if (c.Length > LongitudMaxima)
            return $"La contraseña no puede exceder {LongitudMaxima} caracteres.";
        if (!c.Any(char.IsUpper))
            return "La contraseña debe incluir al menos una mayúscula.";
        if (!c.Any(char.IsLower))
            return "La contraseña debe incluir al menos una minúscula.";
        if (!c.Any(char.IsDigit))
            return "La contraseña debe incluir al menos un número.";
        if (!c.Any(ch => !char.IsLetterOrDigit(ch) && !char.IsWhiteSpace(ch)))
            return "La contraseña debe incluir al menos un carácter especial.";

        return null;
    }
}
