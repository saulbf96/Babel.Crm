namespace UnoContact.Crm.Application.Acceso;

public interface IServicioCambioContrasena
{
    /// <summary>Cambia la contraseña del usuario. Regresa null si se cambió, o el mensaje de por qué no.</summary>
    Task<string?> CambiarAsync(int idUsuario, string? nueva, CancellationToken cancelacion = default);
}

/// <summary>
/// Cambio de contraseña (equivale a FRM_CAMBIOPASS) con la política del CRM:
/// regla de composición, distinta a la actual y a las últimas <see cref="PoliticaContrasena.ContrasenasRecordadas"/>.
/// Al cambiarla se reinicia la vigencia de <see cref="PoliticaContrasena.DiasVigencia"/> días.
/// </summary>
public sealed class ServicioCambioContrasena(IRepositorioUsuarios repositorio) : IServicioCambioContrasena
{
    public const string MensajeIgualActual = "La contraseña nueva no puede ser igual a la actual.";

    public static readonly string MensajeIgualAnterior =
        $"No puedes reutilizar ninguna de tus últimas {PoliticaContrasena.ContrasenasRecordadas} contraseñas.";

    public async Task<string?> CambiarAsync(int idUsuario, string? nueva, CancellationToken cancelacion = default)
    {
        var error = PoliticaContrasena.Validar(nueva);
        if (error is not null) return error;

        var reuso = await repositorio.RevisarReusoAsync(
            idUsuario, nueva!, PoliticaContrasena.ContrasenasRecordadas, cancelacion);
        switch (reuso)
        {
            case ReusoContrasena.Actual: return MensajeIgualActual;
            case ReusoContrasena.Anterior: return MensajeIgualAnterior;
        }

        await repositorio.CambiarContrasenaAsync(idUsuario, nueva!, cancelacion);
        return null;
    }
}
