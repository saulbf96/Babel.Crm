using System.Data;
using System.Text.Json;
using UnoContact.Crm.Application.Abstracciones;
using UnoContact.Crm.Application.Adm;

namespace UnoContact.Crm.Infrastructure.Adm;

/// <summary>Staging de cargas de asignaciones en BABEL_UNIFICADA.</summary>
public sealed class RepositorioCargas(IEjecutorProcedimientos ejecutor) : IRepositorioCargas
{
    private const string Base = "BABEL_UNIFICADA";

    public Task<IReadOnlyList<ProcesoAsignacionDto>> ConsultarProcesosAsync(CancellationToken cancelacion = default) =>
        ejecutor.ConsultarAsync(
            $"{Base}.adm.USP_CONSULTA_PROCESOS",
            [],
            r => new ProcesoAsignacionDto(
                IdProceso: Convert.ToByte(r["IdProceso"]),
                Nombre: Convert.ToString(r["Nombre"]) ?? string.Empty,
                Descripcion: r["Descripcion"] is DBNull ? null : Convert.ToString(r["Descripcion"])),
            cancelacion);

    public Task<IReadOnlyList<CargaAsignacionResumen>> ConsultarAsync(
        byte? idCartera, CancellationToken cancelacion = default) =>
        ejecutor.ConsultarAsync(
            $"{Base}.adm.USP_CONSULTA_CARGAS",
            [new ParametroSp("IdCartera", idCartera, DbType.Byte)],
            r => new CargaAsignacionResumen(
                IdCarga: Convert.ToInt32(r["IdCarga"]),
                IdCartera: Convert.ToByte(r["IdCartera"]),
                Cartera: Convert.ToString(r["Cartera"]) ?? string.Empty,
                Proceso: Convert.ToByte(r["Proceso"]),
                ProcesoNombre: Convert.ToString(r["ProcesoNombre"]) ?? string.Empty,
                NombreArchivo: Convert.ToString(r["NombreArchivo"]) ?? string.Empty,
                Estatus: Convert.ToString(r["Estatus"]) ?? string.Empty,
                TotalRegistros: Convert.ToInt32(r["TotalRegistros"]),
                Procesados: Convert.ToInt32(r["Procesados"]),
                Errores: Convert.ToInt32(r["Errores"]),
                Mensaje: r["Mensaje"] is DBNull ? null : Convert.ToString(r["Mensaje"]),
                Usuario: r["Usuario"] is DBNull ? null : Convert.ToString(r["Usuario"]),
                FechaInicio: Convert.ToDateTime(r["FechaInicio"]),
                FechaFin: r["FechaFin"] is DBNull ? null : Convert.ToDateTime(r["FechaFin"])),
            cancelacion);

    public async Task<ResultadoCargaAsignacion> CrearAsync(
        SolicitudCargaAsignacion solicitud,
        int idUsuario,
        string usuario,
        CancellationToken cancelacion = default)
    {
        var creada = await ejecutor.ConsultarAsync(
            $"{Base}.adm.USP_CREA_CARGA",
            [
                new ParametroSp("IdCartera", solicitud.IdCartera, DbType.Byte),
                new ParametroSp("Proceso", solicitud.Proceso, DbType.Byte),
                new ParametroSp("NombreArchivo", solicitud.NombreArchivo, DbType.String, 260),
                new ParametroSp("RutaArchivo", solicitud.RutaArchivo, DbType.String, 500),
                new ParametroSp("IdUsuario", idUsuario, DbType.Int32),
                new ParametroSp("Usuario", usuario, DbType.AnsiString, 50),
            ],
            r => new
            {
                IdCarga = Convert.ToInt32(r["IdCarga"]),
                Mensaje = Convert.ToString(r["Mensaje"]) ?? string.Empty,
            },
            cancelacion);

        if (creada.Count == 0)
            throw new InvalidOperationException("La carga no devolvió identificador.");

        var idCarga = creada[0].IdCarga;
        var totalFilas = solicitud.Filas?.Count ?? 0;

        if (totalFilas > 0)
        {
            var json = JsonSerializer.Serialize(solicitud.Filas);
            await ejecutor.EjecutarAsync(
                $"{Base}.adm.USP_AGREGA_DETALLE_LOTE",
                [
                    new ParametroSp("IdCarga", idCarga, DbType.Int32),
                    new ParametroSp("FilasJson", json, DbType.String, -1),
                ],
                cancelacion);
        }

        await ejecutor.EjecutarAsync(
            $"{Base}.adm.USP_ACTUALIZA_CARGA",
            [
                new ParametroSp("IdCarga", idCarga, DbType.Int32),
                new ParametroSp("Estatus", "RECIBIDA", DbType.AnsiString, 20),
                new ParametroSp("TotalRegistros", totalFilas, DbType.Int32),
                new ParametroSp("Procesados", 0, DbType.Int32),
                new ParametroSp("Errores", 0, DbType.Int32),
                new ParametroSp("Mensaje", "Carga recibida. Pendiente de validación.", DbType.String, 1000),
            ],
            cancelacion);

        return new ResultadoCargaAsignacion(idCarga, totalFilas, creada[0].Mensaje);
    }
}
