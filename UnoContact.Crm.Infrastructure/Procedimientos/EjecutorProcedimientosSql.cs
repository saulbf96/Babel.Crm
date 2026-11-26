using System.Data;
using System.Data.Common;
using System.Text.RegularExpressions;
using UnoContact.Crm.Application.Abstracciones;
using UnoContact.Crm.Infrastructure.Persistencia;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace UnoContact.Crm.Infrastructure.Procedimientos;

public sealed class OpcionesBaseDatos
{
    public const string Seccion = "BaseDatos";

    /// <summary>Tiempo máximo por comando en segundos. BABEL usaba 0 (infinito); aquí siempre hay límite.</summary>
    public int TiempoEsperaSegundos { get; set; } = 60;
}

/// <summary>
/// Ejecuta procedimientos almacenados con parámetros tipados (CommandType.StoredProcedure).
/// El nombre del procedimiento se valida contra una lista de caracteres permitidos y los valores
/// nunca se concatenan al texto SQL.
/// </summary>
public sealed partial class EjecutorProcedimientosSql(
    UnoContactDbContext contexto,
    IOptions<OpcionesBaseDatos> opciones,
    ILogger<EjecutorProcedimientosSql> bitacora) : IEjecutorProcedimientos
{
    // BASE.ESQUEMA.PROCEDIMIENTO, BASE..PROCEDIMIENTO, ESQUEMA.PROCEDIMIENTO o PROCEDIMIENTO
    [GeneratedRegex(@"^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z0-9_]*){0,2}$")]
    private static partial Regex NombreValido();

    public async Task<IReadOnlyList<T>> ConsultarAsync<T>(
        string procedimiento,
        IEnumerable<ParametroSp> parametros,
        Func<IDataRecord, T> mapear,
        CancellationToken cancelacion = default)
    {
        await using var comando = await CrearComandoAsync(procedimiento, parametros, cancelacion);
        await using var lector = await comando.ExecuteReaderAsync(cancelacion);

        var resultado = new List<T>();
        while (await lector.ReadAsync(cancelacion))
        {
            resultado.Add(mapear(lector));
        }

        return resultado;
    }

    public async Task<int> EjecutarAsync(
        string procedimiento,
        IEnumerable<ParametroSp> parametros,
        CancellationToken cancelacion = default)
    {
        await using var comando = await CrearComandoAsync(procedimiento, parametros, cancelacion);
        return await comando.ExecuteNonQueryAsync(cancelacion);
    }

    private async Task<DbCommand> CrearComandoAsync(
        string procedimiento,
        IEnumerable<ParametroSp> parametros,
        CancellationToken cancelacion)
    {
        if (string.IsNullOrWhiteSpace(procedimiento) || !NombreValido().IsMatch(procedimiento))
        {
            throw new ArgumentException("Nombre de procedimiento almacenado no válido.", nameof(procedimiento));
        }

        var conexion = contexto.Database.GetDbConnection();
        if (conexion.State != ConnectionState.Open)
        {
            await contexto.Database.OpenConnectionAsync(cancelacion);
        }

        var comando = conexion.CreateCommand();
        comando.CommandText = procedimiento;
        comando.CommandType = CommandType.StoredProcedure;
        comando.CommandTimeout = opciones.Value.TiempoEsperaSegundos;
        comando.Transaction = contexto.Database.CurrentTransaction?.GetDbTransaction();

        foreach (var p in parametros)
        {
            var parametro = comando.CreateParameter();
            parametro.ParameterName = p.Nombre.StartsWith('@') ? p.Nombre : "@" + p.Nombre;
            parametro.Value = p.Valor ?? DBNull.Value;
            parametro.Direction = p.Direccion;
            if (p.Tipo is { } tipo) parametro.DbType = tipo;
            if (p.Tamano is { } tamano) parametro.Size = tamano;
            comando.Parameters.Add(parametro);
        }

        // Solo se registra el nombre del procedimiento: los valores pueden traer datos personales.
        LogEjecucion(bitacora, procedimiento);
        return comando;
    }

    [LoggerMessage(Level = LogLevel.Debug, Message = "Ejecutando procedimiento {Procedimiento}")]
    private static partial void LogEjecucion(ILogger logger, string procedimiento);
}
