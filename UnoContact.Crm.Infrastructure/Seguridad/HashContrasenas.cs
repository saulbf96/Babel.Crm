using System.Security.Cryptography;

namespace UnoContact.Crm.Infrastructure.Seguridad;

/// <summary>Cifra y verifica contraseñas con PBKDF2 (SHA-256). La contraseña nunca se guarda en claro.</summary>
public interface IHashContrasenas
{
    string Hashear(string contrasena);
    bool Verificar(string hashGuardado, string contrasena);
}

/// <summary>
/// Formato: PBKDF2$SHA256$&lt;iteraciones&gt;$&lt;salt base64&gt;$&lt;clave base64&gt;.
/// La comparación es de tiempo fijo para no filtrar información por el tiempo de respuesta.
/// </summary>
public sealed class HashContrasenasPbkdf2 : IHashContrasenas
{
    private const int Iteraciones = 100_000;
    private const int TamanoSalt = 16;
    private const int TamanoClave = 32;
    private static readonly HashAlgorithmName Algoritmo = HashAlgorithmName.SHA256;

    public string Hashear(string contrasena)
    {
        var salt = RandomNumberGenerator.GetBytes(TamanoSalt);
        var clave = Rfc2898DeriveBytes.Pbkdf2(contrasena, salt, Iteraciones, Algoritmo, TamanoClave);
        return $"PBKDF2$SHA256${Iteraciones}${Convert.ToBase64String(salt)}${Convert.ToBase64String(clave)}";
    }

    public bool Verificar(string hashGuardado, string contrasena)
    {
        if (string.IsNullOrEmpty(hashGuardado)) return false;

        var partes = hashGuardado.Split('$');
        if (partes.Length != 5 || partes[0] != "PBKDF2" || partes[1] != "SHA256") return false;
        if (!int.TryParse(partes[2], out var iteraciones) || iteraciones <= 0) return false;

        byte[] salt, claveEsperada;
        try
        {
            salt = Convert.FromBase64String(partes[3]);
            claveEsperada = Convert.FromBase64String(partes[4]);
        }
        catch (FormatException)
        {
            return false;
        }

        var claveCalculada = Rfc2898DeriveBytes.Pbkdf2(contrasena, salt, iteraciones, Algoritmo, claveEsperada.Length);
        return CryptographicOperations.FixedTimeEquals(claveCalculada, claveEsperada);
    }
}
