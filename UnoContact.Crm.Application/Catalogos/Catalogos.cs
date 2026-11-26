namespace UnoContact.Crm.Application.Catalogos;

/// <summary>Cartera visible para el usuario (cart.USP_CONSULTA_CARTERAS).</summary>
public sealed record CarteraDto(
    byte IdCartera,
    string Nombre,
    byte IdCliente,
    string Cliente,
    byte? IdBaseLegacy,
    byte? IdDepartamento);

public sealed record PuestoDto(byte IdPuesto, string Nombre, string Tipo, byte Gerarquia);

public sealed record DepartamentoDto(byte IdDepartamento, string Nombre, string Tipo);

public sealed record SexoDto(byte IdSexo, string Nombre);

public sealed record TurnoDto(byte IdTurno, string Nombre);

/// <summary>Todos los catálogos que necesitan las pantallas de Administración.</summary>
public sealed record CatalogosDto(
    IReadOnlyList<CarteraDto> Carteras,
    IReadOnlyList<PuestoDto> Puestos,
    IReadOnlyList<DepartamentoDto> Departamentos,
    IReadOnlyList<SexoDto> Sexos,
    IReadOnlyList<TurnoDto> Turnos);

public interface IRepositorioCatalogos
{
    Task<IReadOnlyList<CarteraDto>> ConsultarCarterasAsync(int idUsuario, CancellationToken cancelacion = default);
    Task<IReadOnlyList<PuestoDto>> ConsultarPuestosAsync(CancellationToken cancelacion = default);
    Task<IReadOnlyList<DepartamentoDto>> ConsultarDepartamentosAsync(CancellationToken cancelacion = default);
    Task<IReadOnlyList<SexoDto>> ConsultarSexosAsync(CancellationToken cancelacion = default);
    Task<IReadOnlyList<TurnoDto>> ConsultarTurnosAsync(CancellationToken cancelacion = default);
}

public interface IServicioCatalogos
{
    Task<CatalogosDto> ConsultarAsync(CancellationToken cancelacion = default);
}
