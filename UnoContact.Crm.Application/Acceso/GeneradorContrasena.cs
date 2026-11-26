using System.Security.Cryptography;

namespace UnoContact.Crm.Application.Acceso;

/// <summary>
/// Contraseña temporal ÚNICA por persona (alta y "Restablecer"), 26/11/2026.
/// Cumple <see cref="PoliticaContrasena"/> (mayúscula, minúscula, número y especial) y evita
/// caracteres que se confunden al dictarla o copiarla (I/l/1, O/0).
/// Se muestra una sola vez al administrador; al entrar, la persona debe cambiarla.
/// </summary>
public static class GeneradorContrasena
{
    private const string Mayusculas = "ABCDEFGHJKLMNPQRSTUVWXYZ";
    private const string Minusculas = "abcdefghijkmnpqrstuvwxyz";
    private const string Numeros = "23456789";
    private const string Especiales = "#$%&*+?!@";
    public const int Largo = 10;

    public static string Generar()
    {
        var todos = Mayusculas + Minusculas + Numeros + Especiales;
        var c = new List<char>
        {
            Uno(Mayusculas), Uno(Minusculas), Uno(Numeros), Uno(Especiales),
        };
        while (c.Count < Largo) c.Add(Uno(todos));

        // Revolver (Fisher-Yates con números aleatorios criptográficos).
        for (var i = c.Count - 1; i > 0; i--)
        {
            var j = RandomNumberGenerator.GetInt32(i + 1);
            (c[i], c[j]) = (c[j], c[i]);
        }
        return new string(c.ToArray());
    }

    private static char Uno(string conjunto) => conjunto[RandomNumberGenerator.GetInt32(conjunto.Length)];
}
