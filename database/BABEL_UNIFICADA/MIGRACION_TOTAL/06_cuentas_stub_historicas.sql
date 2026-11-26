/*
  06_cuentas_stub_historicas.sql
  Crea cuentas stub (Activo=0) para controles históricos presentes en HIEC/NEMF
  pero ausentes en ope.Cuenta. Permite normalizar evolución/mora sin perder FK.
  Idempotente por UQ_Cuenta_Legacy (IdCartera, IdControlLegacy).
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

PRINT '== Cuentas stub históricas ==';

;WITH faltantes AS (
    SELECT DISTINCT h.__IdCartera AS IdCartera, TRY_CONVERT(int, h.HIEC_ID_CONTROL) AS IdControlLegacy
    FROM legacy.HIEC_EVOLUCION_CUENTA h
    LEFT JOIN ope.Cuenta c ON c.IdCartera=h.__IdCartera AND c.IdControlLegacy=TRY_CONVERT(int,h.HIEC_ID_CONTROL)
    WHERE c.IdCuenta IS NULL AND TRY_CONVERT(int,h.HIEC_ID_CONTROL) IS NOT NULL
    UNION
    SELECT DISTINCT m.__IdCartera, TRY_CONVERT(int, m.NEMF_ID_CONTROL)
    FROM legacy.NEMF_MORA_FUENTE_INGRESO m
    LEFT JOIN ope.Cuenta c ON c.IdCartera=m.__IdCartera AND c.IdControlLegacy=TRY_CONVERT(int,m.NEMF_ID_CONTROL)
    WHERE c.IdCuenta IS NULL AND TRY_CONVERT(int,m.NEMF_ID_CONTROL) IS NOT NULL
)
INSERT INTO ope.Cuenta (
    IdCartera, IdControlLegacy, NumeroCuenta, NombreCliente, SituacionCuenta,
    RazonMora, Saldo, IdSegmento, IdProducto, IdCampana, IdEmpleado, Activo, FechaRegistro)
SELECT
    f.IdCartera,
    f.IdControlLegacy,
    CONCAT('HIST-', f.IdControlLegacy),
    NULL,
    'HISTORICO_SIN_NECU',
    NULL,
    NULL,
    0, 0, 0,
    NULL,
    0,
    SYSDATETIME()
FROM faltantes f
WHERE NOT EXISTS (
    SELECT 1 FROM ope.Cuenta c
    WHERE c.IdCartera = f.IdCartera AND c.IdControlLegacy = f.IdControlLegacy
);
PRINT CONCAT('Cuentas stub insertadas: ', @@ROWCOUNT);
GO

-- Ocultar stubs en consulta normal (solo Activo=1)
CREATE OR ALTER PROCEDURE ope.USP_CONSULTA_CUENTAS
    @IdCartera tinyint,
    @Texto varchar(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM cart.Cartera WHERE IdCartera = @IdCartera AND Activo = 1)
        THROW 50060, 'La cartera de la sesión no está activa.', 1;

    DECLARE @Filtro varchar(100) = NULLIF(LTRIM(RTRIM(@Texto)), '');

    SELECT TOP (200)
        c.IdCuenta,
        c.IdCartera,
        ca.Nombre AS Cartera,
        c.IdControlLegacy,
        c.NumeroCuenta,
        c.NombreCliente,
        c.SituacionCuenta,
        c.RazonMora,
        c.Saldo,
        e.NombreCompleto AS Empleado,
        c.Activo,
        c.FechaRegistro
    FROM ope.Cuenta c
    JOIN cart.Cartera ca ON ca.IdCartera = c.IdCartera
    LEFT JOIN (
        SELECT e.IdEmpleado, CONCAT_WS(' ', e.Nombre, e.Paterno, e.Materno) AS NombreCompleto
        FROM rh.Empleado e
    ) e ON e.IdEmpleado = c.IdEmpleado
    WHERE c.IdCartera = @IdCartera
      AND c.Activo = 1
      AND (@Filtro IS NULL
           OR c.NumeroCuenta LIKE '%' + @Filtro + '%'
           OR c.NombreCliente LIKE '%' + @Filtro + '%'
           OR CONVERT(varchar(20), c.IdControlLegacy) = @Filtro)
    ORDER BY c.FechaRegistro DESC, c.IdCuenta DESC;
END;
GO

PRINT '== Stubs creados y USP_CONSULTA_CUENTAS ajustada (Activo=1) ==';
