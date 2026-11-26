using UnoContact.Crm.Application.Acceso;
using Microsoft.Extensions.Caching.Memory;

namespace UnoContact.Crm.Infrastructure.Identidad;

/// <summary>
/// Intentos fallidos por usuario, en memoria del servidor (ventana de 15 minutos).
/// Si el CRM se publica en varios servidores, cambiar a caché distribuida.
/// </summary>
public sealed class ControlIntentosMemoria(IMemoryCache cache) : IControlIntentos
{
    private static readonly TimeSpan Ventana = TimeSpan.FromMinutes(15);
    private readonly Lock _candado = new();

    public int RegistrarFallo(string usuario)
    {
        lock (_candado)
        {
            var fallos = cache.TryGetValue(Clave(usuario), out int actual) ? actual + 1 : 1;
            cache.Set(Clave(usuario), fallos, Ventana);
            return fallos;
        }
    }

    public void Reiniciar(string usuario) => cache.Remove(Clave(usuario));

    private static string Clave(string usuario) => "intentos-acceso:" + usuario;
}
