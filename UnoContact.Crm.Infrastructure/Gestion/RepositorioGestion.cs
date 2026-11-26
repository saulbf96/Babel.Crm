using System.Data;
using UnoContact.Crm.Application.Abstracciones;
using UnoContact.Crm.Application.Gestion;

namespace UnoContact.Crm.Infrastructure.Gestion;

/// <summary>
/// Acceso a las tablas ope.* de Gestión. Todos los procedimientos reciben la
/// cartera de la sesión y validan que la cuenta pertenezca a esa cartera.
/// </summary>
public sealed class RepositorioGestion(IEjecutorProcedimientos ejecutor) : IRepositorioGestion
{
    private const string Base = "BABEL_UNIFICADA.ope.";

    public Task<IReadOnlyList<TipoGestionDto>> ConsultarTiposAsync(CancellationToken cancelacion = default) =>
        ejecutor.ConsultarAsync(
            Base + "USP_CONSULTA_TIPOS_GESTION",
            [],
            r => new TipoGestionDto(
                Convert.ToByte(r["IdTipoGestion"]),
                Convert.ToString(r["Nombre"]) ?? string.Empty),
            cancelacion);

    public Task<IReadOnlyList<CuentaResumen>> ConsultarCuentasAsync(
        byte idCartera, string? texto, CancellationToken cancelacion = default) =>
        ejecutor.ConsultarAsync(
            Base + "USP_CONSULTA_CUENTAS",
            [
                new ParametroSp("IdCartera", idCartera, DbType.Byte),
                new ParametroSp("Texto", texto, DbType.AnsiString, 100),
            ],
            r => new CuentaResumen(
                IdCuenta: Convert.ToInt64(r["IdCuenta"]),
                IdCartera: Convert.ToByte(r["IdCartera"]),
                Cartera: Convert.ToString(r["Cartera"]) ?? string.Empty,
                IdControlLegacy: Convert.ToInt32(r["IdControlLegacy"]),
                NumeroCuenta: Convert.ToString(r["NumeroCuenta"]) ?? string.Empty,
                NombreCliente: LeerTextoNulo(r, "NombreCliente"),
                SituacionCuenta: LeerTextoNulo(r, "SituacionCuenta"),
                RazonMora: LeerTextoNulo(r, "RazonMora"),
                Saldo: LeerDecimalNulo(r, "Saldo"),
                Empleado: LeerTextoNulo(r, "Empleado"),
                Activo: Convert.ToBoolean(r["Activo"]),
                FechaRegistro: Convert.ToDateTime(r["FechaRegistro"])),
            cancelacion);

    public async Task<ResultadoCuenta> CrearCuentaAsync(
        SolicitudCuenta solicitud, byte idCartera, int? idEmpleado, string usuario,
        CancellationToken cancelacion = default)
    {
        var filas = await ejecutor.ConsultarAsync(
            Base + "USP_CREA_CUENTA",
            [
                new ParametroSp("IdCartera", idCartera, DbType.Byte),
                new ParametroSp("IdControlLegacy", solicitud.IdControlLegacy, DbType.Int32),
                new ParametroSp("NumeroCuenta", solicitud.NumeroCuenta, DbType.AnsiString, 50),
                new ParametroSp("NombreCliente", solicitud.NombreCliente, DbType.AnsiString, 200),
                new ParametroSp("SituacionCuenta", solicitud.SituacionCuenta, DbType.AnsiString, 50),
                new ParametroSp("RazonMora", solicitud.RazonMora, DbType.AnsiString, 100),
                new ParametroSp("Saldo", solicitud.Saldo, DbType.Decimal),
                new ParametroSp("IdEmpleado", idEmpleado, DbType.Int32),
                new ParametroSp("Usuario", usuario, DbType.AnsiString, 50),
            ],
            r => new ResultadoCuenta(
                Convert.ToInt64(r["IdCuenta"]),
                Convert.ToString(r["Mensaje"]) ?? string.Empty),
            cancelacion);

        return filas.Count > 0
            ? filas[0]
            : throw new InvalidOperationException("El alta de cuenta no devolvió resultado.");
    }

    public async Task<CuentaDetalle?> ConsultarCuentaAsync(
        byte idCartera, long idCuenta, CancellationToken cancelacion = default)
    {
        var filas = await ejecutor.ConsultarAsync(
            Base + "USP_CONSULTA_CUENTA",
            [
                new ParametroSp("IdCartera", idCartera, DbType.Byte),
                new ParametroSp("IdCuenta", idCuenta, DbType.Int64),
            ],
            r => new CuentaDetalle(
                IdCuenta: Convert.ToInt64(r["IdCuenta"]),
                IdCartera: Convert.ToByte(r["IdCartera"]),
                Cartera: Convert.ToString(r["Cartera"]) ?? string.Empty,
                IdControlLegacy: Convert.ToInt32(r["IdControlLegacy"]),
                NumeroCuenta: Convert.ToString(r["NumeroCuenta"]) ?? string.Empty,
                NombreCliente: LeerTextoNulo(r, "NombreCliente"),
                SituacionCuenta: LeerTextoNulo(r, "SituacionCuenta"),
                RazonMora: LeerTextoNulo(r, "RazonMora"),
                Saldo: LeerDecimalNulo(r, "Saldo"),
                IdSegmento: Convert.ToByte(r["IdSegmento"]),
                IdProducto: Convert.ToByte(r["IdProducto"]),
                IdCampana: Convert.ToByte(r["IdCampana"]),
                Activo: Convert.ToBoolean(r["Activo"]),
                FechaRegistro: Convert.ToDateTime(r["FechaRegistro"])),
            cancelacion);

        return filas.Count > 0 ? filas[0] : null;
    }

    public Task<IReadOnlyList<TelefonoResumen>> ConsultarTelefonosAsync(
        byte idCartera, long idCuenta, CancellationToken cancelacion = default) =>
        ejecutor.ConsultarAsync(
            Base + "USP_CONSULTA_TELEFONOS",
            ParametrosCuenta(idCartera, idCuenta),
            r => new TelefonoResumen(
                IdTelefono: Convert.ToInt64(r["IdTelefono"]),
                Numero: Convert.ToString(r["Numero"]) ?? string.Empty,
                Tipo: LeerTextoNulo(r, "Tipo"),
                Calificacion: LeerByteNulo(r, "Calificacion"),
                Origen: LeerTextoNulo(r, "Origen"),
                Activo: Convert.ToBoolean(r["Activo"]),
                FechaRegistro: Convert.ToDateTime(r["FechaRegistro"])),
            cancelacion);

    public async Task<ResultadoOperacion> RegistrarTelefonoAsync(
        SolicitudTelefono solicitud, byte idCartera, long idCuenta, string usuario,
        CancellationToken cancelacion = default)
    {
        var filas = await ejecutor.ConsultarAsync(
            Base + "USP_REGISTRA_TELEFONO",
            [
                .. ParametrosCuenta(idCartera, idCuenta),
                new ParametroSp("Numero", solicitud.Numero, DbType.AnsiString, 30),
                new ParametroSp("Tipo", solicitud.Tipo, DbType.AnsiString, 20),
                new ParametroSp("Calificacion", solicitud.Calificacion, DbType.Byte),
                new ParametroSp("Origen", solicitud.Origen, DbType.AnsiString, 50),
                new ParametroSp("Usuario", usuario, DbType.AnsiString, 50),
            ],
            MapearResultado,
            cancelacion);

        return Unico(filas, "El registro del teléfono no devolvió resultado.");
    }

    public Task<IReadOnlyList<GestionResumen>> ConsultarGestionesAsync(
        byte idCartera, long idCuenta, CancellationToken cancelacion = default) =>
        ejecutor.ConsultarAsync(
            Base + "USP_CONSULTA_GESTIONES",
            ParametrosCuenta(idCartera, idCuenta),
            r => new GestionResumen(
                IdGestion: Convert.ToInt64(r["IdGestion"]),
                IdTipoGestion: Convert.ToByte(r["IdTipoGestion"]),
                TipoGestion: Convert.ToString(r["TipoGestion"]) ?? string.Empty,
                Comentario: LeerTextoNulo(r, "Comentario"),
                TelefonoMarcado: LeerTextoNulo(r, "TelefonoMarcado"),
                Inbound: Convert.ToBoolean(r["Inbound"]),
                FechaInicio: Convert.ToDateTime(r["FechaInicio"]),
                FechaFin: LeerFechaNulo(r, "FechaFin"),
                TiempoLlamadaSegundos: LeerEnteroNulo(r, "TiempoLlamadaSegundos"),
                TiempoEscrituraSegundos: LeerEnteroNulo(r, "TiempoEscrituraSegundos"),
                Empleado: LeerTextoNulo(r, "Empleado")),
            cancelacion);

    public async Task<ResultadoOperacion> RegistrarGestionAsync(
        SolicitudGestion solicitud, byte idCartera, int idEmpleado, string usuario,
        CancellationToken cancelacion = default)
    {
        var filas = await ejecutor.ConsultarAsync(
            Base + "USP_REGISTRA_GESTION",
            [
                new ParametroSp("IdCartera", idCartera, DbType.Byte),
                new ParametroSp("IdCuenta", solicitud.IdCuenta, DbType.Int64),
                new ParametroSp("IdEmpleado", idEmpleado, DbType.Int32),
                new ParametroSp("IdTipoGestion", solicitud.IdTipoGestion, DbType.Byte),
                new ParametroSp("Comentario", solicitud.Comentario, DbType.String, -1),
                new ParametroSp("IdTelefono", solicitud.IdTelefono, DbType.Int64),
                new ParametroSp("TelefonoMarcado", solicitud.TelefonoMarcado, DbType.AnsiString, 30),
                new ParametroSp("Inbound", solicitud.Inbound, DbType.Boolean),
                new ParametroSp("TiempoLlamadaSegundos", solicitud.TiempoLlamadaSegundos, DbType.Int32),
                new ParametroSp("TiempoEscrituraSegundos", solicitud.TiempoEscrituraSegundos, DbType.Int32),
                new ParametroSp("Usuario", usuario, DbType.AnsiString, 50),
            ],
            MapearResultado,
            cancelacion);

        return Unico(filas, "El registro de la gestión no devolvió resultado.");
    }

    public Task<IReadOnlyList<PromesaResumen>> ConsultarPromesasAsync(
        byte idCartera, long idCuenta, CancellationToken cancelacion = default) =>
        ejecutor.ConsultarAsync(
            Base + "USP_CONSULTA_PROMESAS",
            ParametrosCuenta(idCartera, idCuenta),
            r => new PromesaResumen(
                IdPromesa: Convert.ToInt64(r["IdPromesa"]),
                Monto: Convert.ToDecimal(r["Monto"]),
                FechaPromesa: DateOnly.FromDateTime(Convert.ToDateTime(r["FechaPromesa"])),
                LugarPago: LeerTextoNulo(r, "LugarPago"),
                FuenteIngreso: LeerTextoNulo(r, "FuenteIngreso"),
                RazonMora: LeerTextoNulo(r, "RazonMora"),
                Notas: LeerTextoNulo(r, "Notas"),
                Estatus: Convert.ToString(r["Estatus"]) ?? string.Empty,
                IdGestion: LeerLongNulo(r, "IdGestion"),
                FechaRegistro: Convert.ToDateTime(r["FechaRegistro"])),
            cancelacion);

    public async Task<ResultadoOperacion> RegistrarPromesaAsync(
        SolicitudPromesa solicitud, byte idCartera, string usuario,
        CancellationToken cancelacion = default)
    {
        var filas = await ejecutor.ConsultarAsync(
            Base + "USP_REGISTRA_PROMESA",
            [
                new ParametroSp("IdCartera", idCartera, DbType.Byte),
                new ParametroSp("IdCuenta", solicitud.IdCuenta, DbType.Int64),
                new ParametroSp("IdGestion", solicitud.IdGestion, DbType.Int64),
                new ParametroSp("Monto", solicitud.Monto, DbType.Decimal),
                new ParametroSp("FechaPromesa", solicitud.FechaPromesa.ToDateTime(TimeOnly.MinValue), DbType.Date),
                new ParametroSp("LugarPago", solicitud.LugarPago, DbType.AnsiString, 100),
                new ParametroSp("FuenteIngreso", solicitud.FuenteIngreso, DbType.AnsiString, 100),
                new ParametroSp("RazonMora", solicitud.RazonMora, DbType.AnsiString, 100),
                new ParametroSp("Notas", solicitud.Notas, DbType.String, -1),
                new ParametroSp("Usuario", usuario, DbType.AnsiString, 50),
            ],
            MapearResultado,
            cancelacion);

        return Unico(filas, "El registro de la promesa no devolvió resultado.");
    }

    public Task<IReadOnlyList<DemograficoResumen>> ConsultarDemograficosAsync(
        byte idCartera, long idCuenta, CancellationToken cancelacion = default) =>
        ejecutor.ConsultarAsync(
            Base + "USP_CONSULTA_DEMOGRAFICOS",
            ParametrosCuenta(idCartera, idCuenta),
            r => new DemograficoResumen(
                IdDemografico: Convert.ToInt64(r["IdDemografico"]),
                Calle: LeerTextoNulo(r, "Calle"),
                Colonia: LeerTextoNulo(r, "Colonia"),
                CodigoPostal: LeerTextoNulo(r, "CodigoPostal"),
                Delegacion: LeerTextoNulo(r, "Delegacion"),
                Estado: LeerTextoNulo(r, "Estado"),
                Telefono: LeerTextoNulo(r, "Telefono"),
                Email: LeerTextoNulo(r, "Email"),
                FechaRegistro: Convert.ToDateTime(r["FechaRegistro"])),
            cancelacion);

    private static ParametroSp[] ParametrosCuenta(byte idCartera, long idCuenta) =>
    [
        new ParametroSp("IdCartera", idCartera, DbType.Byte),
        new ParametroSp("IdCuenta", idCuenta, DbType.Int64),
    ];

    private static ResultadoOperacion MapearResultado(IDataRecord r) => new(
        Convert.ToInt64(r["Id"]),
        Convert.ToString(r["Mensaje"]) ?? string.Empty);

    private static ResultadoOperacion Unico(IReadOnlyList<ResultadoOperacion> filas, string mensajeError) =>
        filas.Count > 0 ? filas[0] : throw new InvalidOperationException(mensajeError);

    private static string? LeerTextoNulo(IDataRecord r, string columna)
    {
        var i = r.GetOrdinal(columna);
        return r.IsDBNull(i) ? null : Convert.ToString(r.GetValue(i));
    }

    private static byte? LeerByteNulo(IDataRecord r, string columna)
    {
        var i = r.GetOrdinal(columna);
        return r.IsDBNull(i) ? null : Convert.ToByte(r.GetValue(i));
    }

    private static int? LeerEnteroNulo(IDataRecord r, string columna)
    {
        var i = r.GetOrdinal(columna);
        return r.IsDBNull(i) ? null : Convert.ToInt32(r.GetValue(i));
    }

    private static long? LeerLongNulo(IDataRecord r, string columna)
    {
        var i = r.GetOrdinal(columna);
        return r.IsDBNull(i) ? null : Convert.ToInt64(r.GetValue(i));
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
