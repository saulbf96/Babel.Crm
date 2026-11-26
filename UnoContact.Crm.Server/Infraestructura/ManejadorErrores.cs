using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace UnoContact.Crm.Server.Infraestructura;

/// <summary>
/// Convierte los errores controlados de los SPs (THROW con número 50000+) y las
/// validaciones de la capa de aplicación en respuestas 400 con mensaje claro.
/// Los errores inesperados se registran y se responden como 500 genérico.
/// </summary>
public sealed class ManejadorErrores(ILogger<ManejadorErrores> bitacora) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext contexto,
        Exception excepcion,
        CancellationToken cancelacion)
    {
        var (estado, titulo) = excepcion switch
        {
            SqlException sql when sql.Number >= 50000 => (StatusCodes.Status400BadRequest, sql.Message),
            ArgumentException argumento => (StatusCodes.Status400BadRequest, argumento.Message),
            _ => (StatusCodes.Status500InternalServerError, "No se pudo completar la operación. Intenta de nuevo."),
        };

        if (estado == StatusCodes.Status500InternalServerError)
        {
            bitacora.LogError(excepcion, "Error no controlado en {Ruta}", contexto.Request.Path);
        }
        else
        {
            bitacora.LogWarning("Solicitud rechazada en {Ruta}: {Mensaje}", contexto.Request.Path, titulo);
        }

        contexto.Response.StatusCode = estado;
        await contexto.Response.WriteAsJsonAsync(
            new ProblemDetails { Status = estado, Title = titulo },
            cancelacion);

        return true;
    }
}
