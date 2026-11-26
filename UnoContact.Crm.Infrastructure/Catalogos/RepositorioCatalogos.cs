using System.Data;
using UnoContact.Crm.Application.Abstracciones;
using UnoContact.Crm.Application.Catalogos;

namespace UnoContact.Crm.Infrastructure.Catalogos;

/// <summary>Catálogos de BABEL_UNIFICADA para los combos de Administración.</summary>
public sealed class RepositorioCatalogos(IEjecutorProcedimientos ejecutor) : IRepositorioCatalogos
{
    private const string Base = "BABEL_UNIFICADA"; 

    public Task<IReadOnlyList<CarteraDto>> ConsultarCarterasAsync(int idUsuario, CancellationToken cancelacion = default) =>
        ejecutor.ConsultarAsync(
            $"{Base}.cart.USP_CONSULTA_CARTERAS",
            [new ParametroSp("IdUsuario", idUsuario, DbType.Int32)],
            r => new CarteraDto(
                IdCartera: Convert.ToByte(r["IdCartera"]),
                Nombre: Convert.ToString(r["Nombre"]) ?? string.Empty,
                IdCliente: Convert.ToByte(r["IdCliente"]),
                Cliente: Convert.ToString(r["Cliente"]) ?? string.Empty,
                IdBaseLegacy: r["IdBaseLegacy"] is DBNull ? null : Convert.ToByte(r["IdBaseLegacy"]),
                IdDepartamento: r["IdDepartamento"] is DBNull ? null : Convert.ToByte(r["IdDepartamento"])),
            cancelacion);

    public Task<IReadOnlyList<PuestoDto>> ConsultarPuestosAsync(CancellationToken cancelacion = default) =>
        ejecutor.ConsultarAsync(
            $"{Base}.rh.USP_CONSULTA_PUESTOS",
            [],
            r => new PuestoDto(
                IdPuesto: Convert.ToByte(r["IdPuesto"]),
                Nombre: Convert.ToString(r["Nombre"]) ?? string.Empty,
                Tipo: (Convert.ToString(r["Tipo"]) ?? string.Empty).Trim(),
                Gerarquia: Convert.ToByte(r["Gerarquia"])),
            cancelacion);

    public Task<IReadOnlyList<DepartamentoDto>> ConsultarDepartamentosAsync(CancellationToken cancelacion = default) =>
        ejecutor.ConsultarAsync(
            $"{Base}.rh.USP_CONSULTA_DEPARTAMENTOS",
            [],
            r => new DepartamentoDto(
                IdDepartamento: Convert.ToByte(r["IdDepartamento"]),
                Nombre: Convert.ToString(r["Nombre"]) ?? string.Empty,
                Tipo: (Convert.ToString(r["Tipo"]) ?? string.Empty).Trim()),
            cancelacion);

    public Task<IReadOnlyList<SexoDto>> ConsultarSexosAsync(CancellationToken cancelacion = default) =>
        ejecutor.ConsultarAsync(
            $"{Base}.rh.USP_CONSULTA_SEXOS",
            [],
            r => new SexoDto(
                IdSexo: Convert.ToByte(r["IdSexo"]),
                Nombre: Convert.ToString(r["Nombre"]) ?? string.Empty),
            cancelacion);

    public Task<IReadOnlyList<TurnoDto>> ConsultarTurnosAsync(CancellationToken cancelacion = default) =>
        ejecutor.ConsultarAsync(
            $"{Base}.rh.USP_CONSULTA_TURNOS",
            [],
            r => new TurnoDto(
                IdTurno: Convert.ToByte(r["IdTurno"]),
                Nombre: Convert.ToString(r["Nombre"]) ?? string.Empty),
            cancelacion);
}
