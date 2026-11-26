using System.Data;
using UnoContact.Crm.Application.Abstracciones;
using UnoContact.Crm.Application.Gestion;

namespace UnoContact.Crm.Infrastructure.Gestion;

/// <summary>
/// Acceso a las tablas de Herramientas. Igual que RepositorioGestion, la cartera
/// y el empleado llegan como parámetros desde la sesión, nunca desde el cliente.
/// </summary>
public sealed class RepositorioHerramientas(IEjecutorProcedimientos ejecutor) : IRepositorioHerramientas
{
    private const string Base = "BABEL_UNIFICADA.ope.";

    // ------------------------------- Notas ---------------------------------
    public Task<IReadOnlyList<NotaResumen>> ConsultarNotasAsync(
        byte idCartera, long idCuenta, CancellationToken cancelacion = default) =>
        ejecutor.ConsultarAsync(
            Base + "USP_CONSULTA_NOTAS",
            ParametrosCuenta(idCartera, idCuenta),
            r => new NotaResumen(
                Convert.ToInt64(r["IdNota"]),
                Convert.ToString(r["TipoSeguimiento"]) ?? string.Empty,
                Convert.ToDateTime(r["FechaSeguimiento"]),
                LeerTextoNulo(r, "Telefono"),
                LeerEnteroNulo(r, "Pagos"),
                LeerDecimalNulo(r, "Importe"),
                LeerTextoNulo(r, "Texto"),
                Convert.ToDateTime(r["FechaRegistro"]),
                LeerTextoNulo(r, "Empleado")),
            cancelacion);

    public async Task<ResultadoOperacion> RegistrarNotaAsync(
        SolicitudNota solicitud, byte idCartera, int idEmpleado, CancellationToken cancelacion = default)
    {
        var filas = await ejecutor.ConsultarAsync(
            Base + "USP_REGISTRA_NOTA",
            [
                .. ParametrosCuenta(idCartera, solicitud.IdCuenta),
                new ParametroSp("IdEmpleado", idEmpleado, DbType.Int32),
                new ParametroSp("TipoSeguimiento", solicitud.TipoSeguimiento, DbType.AnsiString, 30),
                new ParametroSp("FechaSeguimiento", solicitud.FechaSeguimiento, DbType.DateTime2),
                new ParametroSp("Telefono", solicitud.Telefono, DbType.AnsiString, 30),
                new ParametroSp("Pagos", solicitud.Pagos, DbType.Int32),
                new ParametroSp("Importe", solicitud.Importe, DbType.Decimal),
                new ParametroSp("Texto", solicitud.Texto, DbType.String, -1),
                new ParametroSp("Usuario", "CRM", DbType.AnsiString, 50),
            ],
            MapearResultado,
            cancelacion);
        return Unico(filas, "El registro de la nota no devolvió resultado.");
    }

    // --------------------------- Bloc de notas ------------------------------
    public async Task<BlocNotaDto> ConsultarBlocNotaAsync(
        byte idCartera, int idEmpleado, CancellationToken cancelacion = default)
    {
        var filas = await ejecutor.ConsultarAsync(
            Base + "USP_CONSULTA_BLOCNOTA",
            ParametrosEmpleado(idCartera, idEmpleado),
            r => new BlocNotaDto(
                Convert.ToString(r["Texto"]) ?? string.Empty,
                LeerFechaNulo(r, "FechaRegistro")),
            cancelacion);
        return filas.Count > 0 ? filas[0] : new BlocNotaDto(string.Empty, null);
    }

    public async Task<ResultadoOperacion> GuardarBlocNotaAsync(
        byte idCartera, int idEmpleado, string texto, CancellationToken cancelacion = default)
    {
        var filas = await ejecutor.ConsultarAsync(
            Base + "USP_GUARDA_BLOCNOTA",
            [
                .. ParametrosEmpleado(idCartera, idEmpleado),
                new ParametroSp("Texto", texto, DbType.String, -1),
            ],
            MapearResultado,
            cancelacion);
        return Unico(filas, "El guardado del bloc no devolvió resultado.");
    }

    // --------------------------- Recesos / break ----------------------------
    public async Task<RecesoActivo> IniciarRecesoAsync(
        byte idCartera, int idEmpleado, string tipoReceso, CancellationToken cancelacion = default)
    {
        var filas = await ejecutor.ConsultarAsync(
            Base + "USP_INICIA_RECESO",
            [
                .. ParametrosEmpleado(idCartera, idEmpleado),
                new ParametroSp("TipoReceso", tipoReceso, DbType.AnsiString, 50),
            ],
            r => new RecesoActivo(
                Convert.ToInt64(r["Id"]),
                Convert.ToDateTime(r["Inicio"]),
                Convert.ToString(r["Mensaje"]) ?? string.Empty),
            cancelacion);
        return UnicoReceso(filas);
    }

    public async Task<ResultadoOperacion> FinalizarRecesoAsync(
        long idReceso, byte idCartera, int idEmpleado, CancellationToken cancelacion = default)
    {
        var filas = await ejecutor.ConsultarAsync(
            Base + "USP_FINALIZA_RECESO",
            [
                new ParametroSp("IdReceso", idReceso, DbType.Int64),
                .. ParametrosEmpleado(idCartera, idEmpleado),
            ],
            MapearResultado,
            cancelacion);
        return Unico(filas, "El cierre del receso no devolvió resultado.");
    }

    public Task<IReadOnlyList<RecesoResumen>> ConsultarRecesosAsync(
        byte idCartera, int idEmpleado, CancellationToken cancelacion = default) =>
        ejecutor.ConsultarAsync(
            Base + "USP_CONSULTA_RECESOS",
            ParametrosEmpleado(idCartera, idEmpleado),
            r => new RecesoResumen(
                Convert.ToInt64(r["IdReceso"]),
                LeerTextoNulo(r, "TipoReceso"),
                Convert.ToDateTime(r["Inicio"]),
                LeerFechaNulo(r, "Fin"),
                LeerEnteroNulo(r, "Minutos")),
            cancelacion);

    // --------------------------- Agendar llamada ----------------------------
    public Task<IReadOnlyList<AgendaResumen>> ConsultarAgendaAsync(
        byte idCartera, long? idCuenta, CancellationToken cancelacion = default) =>
        ejecutor.ConsultarAsync(
            Base + "USP_CONSULTA_AGENDA",
            [
                new ParametroSp("IdCartera", idCartera, DbType.Byte),
                new ParametroSp("IdCuenta", idCuenta, DbType.Int64),
            ],
            r => new AgendaResumen(
                Convert.ToInt64(r["IdAgenda"]),
                Convert.ToInt64(r["IdCuenta"]),
                Convert.ToString(r["NumeroCuenta"]) ?? string.Empty,
                LeerTextoNulo(r, "NombreCliente"),
                Convert.ToDateTime(r["FechaHora"]),
                LeerTextoNulo(r, "Telefono"),
                LeerTextoNulo(r, "Asunto"),
                Convert.ToString(r["Estatus"]) ?? string.Empty,
                LeerTextoNulo(r, "Empleado")),
            cancelacion);

    public async Task<ResultadoOperacion> RegistrarAgendaAsync(
        SolicitudAgenda solicitud, byte idCartera, int idEmpleado, CancellationToken cancelacion = default)
    {
        var filas = await ejecutor.ConsultarAsync(
            Base + "USP_REGISTRA_AGENDA",
            [
                .. ParametrosCuenta(idCartera, solicitud.IdCuenta),
                new ParametroSp("IdEmpleado", idEmpleado, DbType.Int32),
                new ParametroSp("FechaHora", solicitud.FechaHora, DbType.DateTime2),
                new ParametroSp("Telefono", solicitud.Telefono, DbType.AnsiString, 30),
                new ParametroSp("Asunto", solicitud.Asunto, DbType.AnsiString, 200),
            ],
            MapearResultado,
            cancelacion);
        return Unico(filas, "El registro de la agenda no devolvió resultado.");
    }

    public async Task<ResultadoOperacion> CambiarEstatusAgendaAsync(
        long idAgenda, byte idCartera, string estatus, CancellationToken cancelacion = default)
    {
        var filas = await ejecutor.ConsultarAsync(
            Base + "USP_CAMBIA_ESTATUS_AGENDA",
            [
                new ParametroSp("IdAgenda", idAgenda, DbType.Int64),
                new ParametroSp("IdCartera", idCartera, DbType.Byte),
                new ParametroSp("Estatus", estatus, DbType.AnsiString, 20),
            ],
            MapearResultado,
            cancelacion);
        return Unico(filas, "El cambio de estatus no devolvió resultado.");
    }

    // ------------------------ Negociación / Calculadora ---------------------
    public Task<IReadOnlyList<NegociacionResumen>> ConsultarNegociacionesAsync(
        byte idCartera, long idCuenta, CancellationToken cancelacion = default) =>
        ejecutor.ConsultarAsync(
            Base + "USP_CONSULTA_NEGOCIACIONES",
            ParametrosCuenta(idCartera, idCuenta),
            r => new NegociacionResumen(
                Convert.ToInt64(r["IdNegociacion"]),
                LeerTextoNulo(r, "TipoNegociacion"),
                LeerTextoNulo(r, "TipoPago"),
                Convert.ToDecimal(r["MontoOriginal"]),
                Convert.ToDecimal(r["PorcentajeDescuento"]),
                Convert.ToDecimal(r["MontoFinal"]),
                Convert.ToInt32(r["NumeroPagos"]),
                LeerFechaNulo(r, "FechaPrimerPago") is { } fecha ? DateOnly.FromDateTime(fecha) : null,
                LeerTextoNulo(r, "Comentario"),
                Convert.ToDateTime(r["FechaRegistro"]),
                LeerTextoNulo(r, "Empleado")),
            cancelacion);

    public async Task<ResultadoOperacion> RegistrarNegociacionAsync(
        SolicitudNegociacion solicitud, byte idCartera, int idEmpleado, CancellationToken cancelacion = default)
    {
        var filas = await ejecutor.ConsultarAsync(
            Base + "USP_REGISTRA_NEGOCIACION",
            [
                .. ParametrosCuenta(idCartera, solicitud.IdCuenta),
                new ParametroSp("IdEmpleado", idEmpleado, DbType.Int32),
                new ParametroSp("TipoNegociacion", solicitud.TipoNegociacion, DbType.AnsiString, 50),
                new ParametroSp("TipoPago", solicitud.TipoPago, DbType.AnsiString, 50),
                new ParametroSp("MontoOriginal", solicitud.MontoOriginal, DbType.Decimal),
                new ParametroSp("PorcentajeDescuento", solicitud.PorcentajeDescuento, DbType.Decimal),
                new ParametroSp("MontoFinal", solicitud.MontoFinal, DbType.Decimal),
                new ParametroSp("NumeroPagos", solicitud.NumeroPagos, DbType.Int32),
                new ParametroSp("FechaPrimerPago", solicitud.FechaPrimerPago?.ToDateTime(TimeOnly.MinValue), DbType.Date),
                new ParametroSp("Comentario", solicitud.Comentario, DbType.String, -1),
            ],
            MapearResultado,
            cancelacion);
        return Unico(filas, "El registro de la negociación no devolvió resultado.");
    }

    // ------------------------ Actualiza información -------------------------
    public async Task<ResultadoOperacion> ActualizarDemograficoAsync(
        SolicitudActualizaDemografico solicitud, byte idCartera, string usuario, CancellationToken cancelacion = default)
    {
        var filas = await ejecutor.ConsultarAsync(
            Base + "USP_ACTUALIZA_DEMOGRAFICO",
            [
                .. ParametrosCuenta(idCartera, solicitud.IdCuenta),
                new ParametroSp("Calle", solicitud.Calle, DbType.AnsiString, 200),
                new ParametroSp("Colonia", solicitud.Colonia, DbType.AnsiString, 150),
                new ParametroSp("CodigoPostal", solicitud.CodigoPostal, DbType.AnsiString, 10),
                new ParametroSp("Delegacion", solicitud.Delegacion, DbType.AnsiString, 150),
                new ParametroSp("Estado", solicitud.Estado, DbType.AnsiString, 100),
                new ParametroSp("Telefono", solicitud.Telefono, DbType.AnsiString, 30),
                new ParametroSp("Email", solicitud.Email, DbType.AnsiString, 150),
                new ParametroSp("Usuario", usuario, DbType.AnsiString, 50),
            ],
            MapearResultado,
            cancelacion);
        return Unico(filas, "La actualización no devolvió resultado.");
    }

    private static ParametroSp[] ParametrosCuenta(byte idCartera, long idCuenta) =>
    [
        new ParametroSp("IdCartera", idCartera, DbType.Byte),
        new ParametroSp("IdCuenta", idCuenta, DbType.Int64),
    ];

    private static ParametroSp[] ParametrosEmpleado(byte idCartera, int idEmpleado) =>
    [
        new ParametroSp("IdCartera", idCartera, DbType.Byte),
        new ParametroSp("IdEmpleado", idEmpleado, DbType.Int32),
    ];

    private static ResultadoOperacion MapearResultado(IDataRecord r) => new(
        Convert.ToInt64(r["Id"]),
        Convert.ToString(r["Mensaje"]) ?? string.Empty);

    private static RecesoActivo UnicoReceso(IReadOnlyList<RecesoActivo> filas) =>
        filas.Count > 0 ? filas[0] : throw new InvalidOperationException("El inicio de receso no devolvió resultado.");

    private static ResultadoOperacion Unico(IReadOnlyList<ResultadoOperacion> filas, string mensajeError) =>
        filas.Count > 0 ? filas[0] : throw new InvalidOperationException(mensajeError);

    private static string? LeerTextoNulo(IDataRecord r, string columna)
    {
        var i = r.GetOrdinal(columna);
        return r.IsDBNull(i) ? null : Convert.ToString(r.GetValue(i));
    }

    private static int? LeerEnteroNulo(IDataRecord r, string columna)
    {
        var i = r.GetOrdinal(columna);
        return r.IsDBNull(i) ? null : Convert.ToInt32(r.GetValue(i));
    }

    private static decimal? LeerDecimalNulo(IDataRecord r, string columna)
    {
        var i = r.GetOrdinal(columna);
        return r.IsDBNull(i) ? null : Convert.ToDecimal(r.GetValue(i));
    }

    private static DateTime? LeerFechaNulo(IDataRecord r, string columna)
    {
        var i = r.GetOrdinal(columna);
        return r.IsDBNull(i) ? null : Convert.ToDateTime(r.GetValue(i));
    }
}
