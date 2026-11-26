using System.Data;
using UnoContact.Crm.Application.Abstracciones;
using UnoContact.Crm.Application.Acceso;
using UnoContact.Crm.Application.Rh;
using UnoContact.Crm.Infrastructure.Seguridad;

namespace UnoContact.Crm.Infrastructure.Rh;

/// <summary>
/// Lee empleados de la base única BABEL_UNIFICADA mediante el procedimiento parametrizado
/// rh.USP_CONSULTA_EMPLEADOS (nombre en 3 partes para no depender de la base por defecto de la conexión).
/// </summary>
public sealed class RepositorioEmpleados(
    IEjecutorProcedimientos ejecutor,
    IHashContrasenas hash) : IRepositorioEmpleados
{
    private const string Procedimiento = "BABEL_UNIFICADA.rh.USP_CONSULTA_EMPLEADOS";

    public Task<IReadOnlyList<EmpleadoResumen>> ConsultarAsync(FiltroEmpleados filtro, CancellationToken cancelacion = default)
    {
        var parametros = new[]
        {
            new ParametroSp("IdCartera",   filtro.IdCartera,  DbType.Byte),
            new ParametroSp("Nombre",      filtro.Nombre,     DbType.String, 100),
            new ParametroSp("IdPuesto",    filtro.IdPuesto,   DbType.Byte),
            new ParametroSp("SoloActivos", filtro.SoloActivos, DbType.Boolean),
        };

        return ejecutor.ConsultarAsync(Procedimiento, parametros, Mapear, cancelacion);
    }

    public async Task<ResultadoAltaEmpleado> AltaAsync(
        SolicitudAltaEmpleado solicitud,
        byte idCartera,
        string usuario,
        string? ajustesPermisos,
        CancellationToken cancelacion = default)
    {
        // Contraseña temporal ÚNICA por persona (se regresa para mostrarla una sola vez).
        var temporal = GeneradorContrasena.Generar();
        var parametros = new[]
        {
            new ParametroSp("IdCartera", idCartera, DbType.Byte),
            new ParametroSp("IdPuesto",  solicitud.IdPuesto,  DbType.Byte),
            new ParametroSp("IdSexo",    solicitud.IdSexo,    DbType.Byte),
            new ParametroSp("HoraEntrada", solicitud.HoraEntrada?.ToTimeSpan(), DbType.Time),
            new ParametroSp("HoraSalida",  solicitud.HoraSalida?.ToTimeSpan(),  DbType.Time),
            new ParametroSp("Nombre",    solicitud.Nombre,    DbType.AnsiString, 100),
            new ParametroSp("Paterno",   solicitud.Paterno,   DbType.AnsiString, 100),
            new ParametroSp("Materno",   solicitud.Materno,   DbType.AnsiString, 100),
            new ParametroSp("Usuario",   usuario,             DbType.AnsiString, 50),
            new ParametroSp("ConfirmarHomonimo", solicitud.ConfirmarHomonimo, DbType.Boolean),
            new ParametroSp("AplicaHorario", solicitud.AplicaHorario, DbType.Boolean),
            // El alta crea también el usuario (misma transacción en la base).
            new ParametroSp("UsuarioBase", ReglasUsuario.Base(solicitud.Nombre, solicitud.Paterno), DbType.AnsiString, 45),
            new ParametroSp("HashContrasena", hash.Hashear(temporal), DbType.AnsiString, 200),
            new ParametroSp("Permisos", ajustesPermisos, DbType.AnsiString, -1),
            // Las demás campañas elegidas (la principal va en IdCartera).
            new ParametroSp("CarterasAcceso",
                solicitud.Carteras is { Count: > 0 } cs ? string.Join(',', cs.Where(c => c != idCartera)) : null,
                DbType.AnsiString, -1),
        };

        var filas = await ejecutor.ConsultarAsync(
            "BABEL_UNIFICADA.rh.USP_ALTA_EMPLEADO",
            parametros,
            r => new ResultadoAltaEmpleado(
                Convert.ToInt32(r["IdEmpleado"]),
                Convert.ToString(r["Mensaje"]) ?? string.Empty,
                Usuario: r["Usuario"] is DBNull ? null : Convert.ToString(r["Usuario"]),
                ContrasenaTemporal: r["Usuario"] is DBNull ? null : temporal),
            cancelacion);

        return filas.Count > 0
            ? filas[0]
            : throw new InvalidOperationException("El alta de empleado no devolvió resultado.");
    }

    public Task<IReadOnlyList<EmpleadoCoincidente>> BuscarDuplicadosAsync(
        string nombre, string paterno, string materno, byte idCartera, CancellationToken cancelacion = default) =>
        ejecutor.ConsultarAsync(
            "BABEL_UNIFICADA.rh.USP_BUSCA_DUPLICADOS",
            [
                new ParametroSp("Nombre", nombre, DbType.AnsiString, 100),
                new ParametroSp("Paterno", paterno, DbType.AnsiString, 100),
                new ParametroSp("Materno", materno, DbType.AnsiString, 100),
                new ParametroSp("IdCartera", idCartera, DbType.Byte),
            ],
            r => new EmpleadoCoincidente(
                IdEmpleado: Convert.ToInt32(r["IdEmpleado"]),
                NombreCompleto: Convert.ToString(r["NombreCompleto"]) ?? string.Empty,
                Puesto: Convert.ToString(r["Puesto"]) ?? string.Empty,
                Activo: Convert.ToBoolean(r["Activo"]),
                FechaIngreso: DateOnly.FromDateTime(Convert.ToDateTime(r["FechaIngreso"])),
                CarteraActiva: r["CarteraActiva"] is DBNull ? null : Convert.ToString(r["CarteraActiva"]),
                EnEstaCartera: Convert.ToBoolean(r["EnEstaCartera"]),
                TieneAcceso: Convert.ToBoolean(r["TieneAcceso"]),
                Usuario: r["Usuario"] is DBNull ? null : Convert.ToString(r["Usuario"])),
            cancelacion);

    public Task DarAccesoCarteraAsync(int idEmpleado, byte idCartera, string usuario, CancellationToken cancelacion = default) =>
        ejecutor.EjecutarAsync(
            "BABEL_UNIFICADA.rh.USP_DAR_ACCESO_CARTERA",
            [
                new ParametroSp("IdEmpleado", idEmpleado, DbType.Int32),
                new ParametroSp("IdCartera", idCartera, DbType.Byte),
                new ParametroSp("Usuario", usuario, DbType.AnsiString, 50),
            ],
            cancelacion);

    public Task<IReadOnlyList<AltaRegistrada>> ConsultarAltasAsync(byte idCartera, DateOnly desde, DateOnly hasta, CancellationToken cancelacion = default) =>
        ejecutor.ConsultarAsync(
            "BABEL_UNIFICADA.rh.USP_CONSULTA_ALTAS",
            [
                new ParametroSp("IdCartera", idCartera, DbType.Byte),
                new ParametroSp("Desde", desde.ToDateTime(TimeOnly.MinValue), DbType.Date),
                new ParametroSp("Hasta", hasta.ToDateTime(TimeOnly.MinValue), DbType.Date),
            ],
            r => new AltaRegistrada(
                FechaAlta: Convert.ToDateTime(r["FechaAlta"]),
                RegistradoPor: Convert.ToString(r["RegistradoPor"]) ?? string.Empty,
                NombreCompleto: Convert.ToString(r["NombreCompleto"]) ?? string.Empty,
                Usuario: r["Usuario"] is DBNull ? null : Convert.ToString(r["Usuario"]),
                Puesto: Convert.ToString(r["Puesto"]) ?? string.Empty,
                HoraEntrada: r["HoraEntrada"] is DBNull ? null : TimeOnly.FromTimeSpan((TimeSpan)r["HoraEntrada"]),
                HoraSalida: r["HoraSalida"] is DBNull ? null : TimeOnly.FromTimeSpan((TimeSpan)r["HoraSalida"]),
                AplicaHorario: Convert.ToBoolean(r["AplicaHorario"]),
                Activo: Convert.ToBoolean(r["Activo"])),
            cancelacion);

    public async Task<(int IdUsuario, bool EsRoot, short IdPuesto, IReadOnlyList<AjustePermiso> Ajustes)?> PermisosDeEmpleadoAsync(
        int idEmpleado, CancellationToken cancelacion = default)
    {
        var filas = await ejecutor.ConsultarAsync(
            "BABEL_UNIFICADA.seg.USP_CONSULTA_PERMISOS_EMPLEADO",
            [new ParametroSp("IdEmpleado", idEmpleado, DbType.Int32)],
            r => (IdUsuario: Convert.ToInt32(r["IdUsuario"]),
                  EsRoot: Convert.ToBoolean(r["EsRoot"]),
                  IdPuesto: Convert.ToInt16(r["IdPuesto"]),
                  Clave: r["Clave"] is DBNull ? null : Convert.ToString(r["Clave"]),
                  Concedido: r["Concedido"] is not DBNull && Convert.ToBoolean(r["Concedido"])),
            cancelacion);
        if (filas.Count == 0) return null;
        var f = filas[0];
        return (f.IdUsuario, f.EsRoot, f.IdPuesto,
                filas.Where(x => x.Clave is not null).Select(x => new AjustePermiso(x.Clave!, x.Concedido)).ToList());
    }

    public Task EditarAsync(int idEmpleado, byte idCartera, SolicitudEdicionEmpleado s, string usuario, string? ajustesPermisos, CancellationToken cancelacion = default) =>
        ejecutor.EjecutarAsync(
            "BABEL_UNIFICADA.rh.USP_EDITA_EMPLEADO",
            [
                new ParametroSp("IdEmpleado", idEmpleado, DbType.Int32),
                new ParametroSp("IdCartera", idCartera, DbType.Byte),
                new ParametroSp("Nombre", s.Nombre, DbType.AnsiString, 100),
                new ParametroSp("Paterno", s.Paterno, DbType.AnsiString, 100),
                new ParametroSp("Materno", s.Materno, DbType.AnsiString, 100),
                new ParametroSp("IdPuesto", s.IdPuesto, DbType.Byte),
                new ParametroSp("IdSexo", s.IdSexo, DbType.Byte),
                new ParametroSp("HoraEntrada", s.HoraEntrada?.ToTimeSpan(), DbType.Time),
                new ParametroSp("HoraSalida", s.HoraSalida?.ToTimeSpan(), DbType.Time),
                new ParametroSp("AplicaHorario", s.AplicaHorario, DbType.Boolean),
                new ParametroSp("Usuario", usuario, DbType.AnsiString, 50),
                new ParametroSp("Permisos", ajustesPermisos, DbType.AnsiString, -1),
            ],
            cancelacion);

    private static EmpleadoResumen Mapear(IDataRecord r) => new(
        IdEmpleado: r.GetInt32(r.GetOrdinal("IdEmpleado")),
        Nombre: r.GetString(r.GetOrdinal("Nombre")),
        Paterno: r.GetString(r.GetOrdinal("Paterno")),
        Materno: LeerTextoNulo(r, "Materno"),
        NombreCompleto: r.GetString(r.GetOrdinal("NombreCompleto")),
        Usuario: LeerTextoNulo(r, "Usuario"),
        IdPuesto: r.GetByte(r.GetOrdinal("IdPuesto")),
        Puesto: r.GetString(r.GetOrdinal("Puesto")),
        IdDepartamento: r.GetByte(r.GetOrdinal("IdDepartamento")),
        Departamento: r.GetString(r.GetOrdinal("Departamento")),
        IdCartera: LeerByteNulo(r, "IdCartera"),
        Cartera: LeerTextoNulo(r, "Cartera"),
        IdSexo: r.GetByte(r.GetOrdinal("IdSexo")),
        Sexo: r.GetString(r.GetOrdinal("Sexo")),
        IdTurno: LeerByteNulo(r, "IdTurno"),
        Turno: LeerTextoNulo(r, "Turno"),
        HoraEntrada: LeerHoraNulo(r, "HoraEntrada"),
        HoraSalida: LeerHoraNulo(r, "HoraSalida"),
        AplicaHorario: r.GetBoolean(r.GetOrdinal("AplicaHorario")),
        FechaNacimiento: LeerFechaNulo(r, "FechaNacimiento"),
        FechaIngreso: DateOnly.FromDateTime(r.GetDateTime(r.GetOrdinal("FechaIngreso"))),
        Rfc: LeerTextoNulo(r, "Rfc"),
        Curp: LeerTextoNulo(r, "Curp"),
        Nss: LeerLongNulo(r, "Nss"),
        Email: LeerTextoNulo(r, "Email"),
        Activo: r.GetBoolean(r.GetOrdinal("Activo")),
        FechaRegistro: r.GetDateTime(r.GetOrdinal("FechaRegistro")));

    private static string? LeerTextoNulo(IDataRecord r, string columna)
    {
        var i = r.GetOrdinal(columna);
        return r.IsDBNull(i) ? null : r.GetString(i);
    }

    private static byte? LeerByteNulo(IDataRecord r, string columna)
    {
        var i = r.GetOrdinal(columna);
        return r.IsDBNull(i) ? null : r.GetByte(i);
    }

    private static long? LeerLongNulo(IDataRecord r, string columna)
    {
        var i = r.GetOrdinal(columna);
        return r.IsDBNull(i) ? null : r.GetInt64(i);
    }

    private static TimeOnly? LeerHoraNulo(IDataRecord r, string columna)
    {
        var i = r.GetOrdinal(columna);
        return r.IsDBNull(i) ? null : TimeOnly.FromTimeSpan((TimeSpan)r.GetValue(i));
    }

    private static DateOnly? LeerFechaNulo(IDataRecord r, string columna)
    {
        var i = r.GetOrdinal(columna);
        return r.IsDBNull(i) ? null : DateOnly.FromDateTime(r.GetDateTime(i));
    }
}
