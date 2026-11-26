using System.Globalization;
using System.Text;

namespace UnoContact.Crm.Application.Rh;

/// <summary>
/// Nombre de usuario del sistema = inicial del nombre + apellido paterno, en MAYÚSCULAS,
/// sin acentos, Ñ→N y sin espacios (ej. MARÍA JOSÉ DE LA CRUZ → MDELACRUZ).
/// Si ya existe, la base agrega 2, 3… (misma regla que 18_seg_provisionar_usuarios.ps1).
/// </summary>
public static class ReglasUsuario
{
    public const int LargoMaximoBase = 45;

    public static string Base(string nombre, string paterno)
    {
        var texto = ((nombre ?? string.Empty).Trim().FirstOrDefault() + (paterno ?? string.Empty))
            .Normalize(NormalizationForm.FormD);
        var sb = new StringBuilder();
        foreach (var c in texto)
        {
            if (CharUnicodeInfo.GetUnicodeCategory(c) == UnicodeCategory.NonSpacingMark) continue;
            var m = char.ToUpperInvariant(c);
            if (m is >= 'A' and <= 'Z') sb.Append(m);
        }
        var resultado = sb.ToString();
        return resultado.Length > LargoMaximoBase ? resultado[..LargoMaximoBase] : resultado;
    }
}
