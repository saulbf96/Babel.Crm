using System.Data;

namespace Babel.Crm.Application.Abstracciones;

/// <summary>
/// Parámetro de un procedimiento almacenado. El valor siempre viaja como parámetro,
/// nunca concatenado en el texto SQL (corrige la inyección SQL de los aplicativos de escritorio).
/// </summary>
public sealed record ParametroSp(
    string Nombre,
    object? Valor,
    DbType? Tipo = null,
    int? Tamano = null,
    ParameterDirection Direccion = ParameterDirection.Input);

/// <summary>
/// Ejecuta procedimientos almacenados de las bases de BABEL (CONFIGURACION_APP, ADMINISTRA_APP, etc.).
/// </summary>
public interface IEjecutorProcedimientos
{
    /// <summary>Ejecuta un procedimiento y mapea cada renglón del primer resultado.</summary>
    Task<IReadOnlyList<T>> ConsultarAsync<T>(
        string procedimiento,
        IEnumerable<ParametroSp> parametros,
        Func<IDataRecord, T> mapear,
        CancellationToken cancelacion = default);

    /// <summary>Ejecuta un procedimiento que no devuelve renglones. Regresa los renglones afectados.</summary>
    Task<int> EjecutarAsync(
        string procedimiento,
        IEnumerable<ParametroSp> parametros,
        CancellationToken cancelacion = default);
}
