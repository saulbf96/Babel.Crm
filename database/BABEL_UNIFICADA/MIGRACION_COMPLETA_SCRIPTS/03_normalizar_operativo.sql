/*
  03_normalizar_operativo.sql
  Normaliza datos desde legacy.* (espejo crudo) hacia tablas ope.* usadas por el CRM.
  Idempotente donde es posible (NOT EXISTS por IdRegistroLegacy + IdCartera).
  Regla: mapear empleado legacy con ISNULL(e.IdEmpleadoUnificado, e.IdEmpleado).
  No toca el servidor remoto.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

PRINT '== Normalización operativa desde legacy.* ==';

-- Índices de apoyo para idempotencia
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_MoraFuente_RegistroLegacy' AND object_id=OBJECT_ID('ope.MoraFuenteIngreso'))
    CREATE INDEX IX_MoraFuente_RegistroLegacy ON ope.MoraFuenteIngreso(IdCartera, IdRegistroLegacy);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Evolucion_RegistroLegacy' AND object_id=OBJECT_ID('ope.EvolucionCuenta'))
    CREATE INDEX IX_Evolucion_RegistroLegacy ON ope.EvolucionCuenta(IdCartera, IdRegistroLegacy);
GO

-- ---------------------------------------------------------------------------
-- Mora / Fuente de ingreso (NEMF_MORA_FUENTE_INGRESO)
-- ---------------------------------------------------------------------------
IF OBJECT_ID('legacy.NEMF_MORA_FUENTE_INGRESO','U') IS NOT NULL
BEGIN
    PRINT 'NEMF_MORA_FUENTE_INGRESO -> ope.MoraFuenteIngreso';
    INSERT INTO ope.MoraFuenteIngreso (
        IdCuenta, IdCartera, IdGestion, FuenteIngreso, RazonMora, Intencion, Comentario, IdRegistroLegacy, FechaRegistro)
    SELECT
        c.IdCuenta,
        m.__IdCartera,
        g.IdGestion,
        LEFT(NULLIF(LTRIM(RTRIM(CAST(fi.CAFI_FUENTE_INGRESO AS nvarchar(200)))),''),100),
        LEFT(NULLIF(LTRIM(RTRIM(CAST(rm.CARM_RAZON_MORA AS nvarchar(200)))),''),100),
        NULL,
        NULL,
        TRY_CONVERT(int, m.NEMF_ID_REGISTRO),
        ISNULL(TRY_CONVERT(datetime2(0), m.NEMF_FECHA_REGISTRO), SYSDATETIME())
    FROM legacy.NEMF_MORA_FUENTE_INGRESO m
    JOIN ope.Cuenta c
      ON c.IdCartera = m.__IdCartera
     AND c.IdControlLegacy = TRY_CONVERT(int, m.NEMF_ID_CONTROL)
    LEFT JOIN ope.Gestion g
      ON g.IdCartera = m.__IdCartera
     AND g.IdRegistroLegacy = TRY_CONVERT(int, m.NEMF_ID_GESTION)
    LEFT JOIN legacy.CAFI_FUENTE_INGRESO fi
      ON fi.__IdCartera = m.__IdCartera
     AND TRY_CONVERT(int, fi.CAFI_ID_FUENTE_INGRESO) = TRY_CONVERT(int, m.NEMF_ID_FUENTE_INGRESO)
    LEFT JOIN legacy.CARM_RAZON_MORA rm
      ON rm.__IdCartera = m.__IdCartera
     AND TRY_CONVERT(int, rm.CARM_ID_RAZON_MORA) = TRY_CONVERT(int, m.NEMF_ID_RAZON_MORA)
    WHERE TRY_CONVERT(int, m.NEMF_ID_REGISTRO) IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM ope.MoraFuenteIngreso x
          WHERE x.IdCartera = m.__IdCartera
            AND x.IdRegistroLegacy = TRY_CONVERT(int, m.NEMF_ID_REGISTRO)
      );
    PRINT CONCAT('  filas: ', @@ROWCOUNT);
END
GO

-- ---------------------------------------------------------------------------
-- Evolución de cuenta (HIEC_EVOLUCION_CUENTA)
-- Estructura legacy: registro por cambio de situación; no hay campo/valor antes/después.
-- Se preserva como Campo='SITUACION_CUENTA' con ValorNuevo=IdSituacionCuenta.
-- ---------------------------------------------------------------------------
IF OBJECT_ID('legacy.HIEC_EVOLUCION_CUENTA','U') IS NOT NULL
BEGIN
    PRINT 'HIEC_EVOLUCION_CUENTA -> ope.EvolucionCuenta';
    INSERT INTO ope.EvolucionCuenta (
        IdCuenta, IdCartera, FechaEvento, Campo, ValorAnterior, ValorNuevo, IdRegistroLegacy, FechaRegistro)
    SELECT
        c.IdCuenta,
        h.__IdCartera,
        TRY_CONVERT(datetime2(0), h.HIEC_FECHA_REGISTRO),
        'SITUACION_CUENTA',
        NULL,
        LEFT(NULLIF(LTRIM(RTRIM(CAST(h.HIEC_ID_SITUACION_CUENTA AS nvarchar(100)))),''),300),
        TRY_CONVERT(int, h.HIEC_ID_REGISTRO),
        ISNULL(TRY_CONVERT(datetime2(0), h.HIEC_FECHA_REGISTRO), SYSDATETIME())
    FROM legacy.HIEC_EVOLUCION_CUENTA h
    JOIN ope.Cuenta c
      ON c.IdCartera = h.__IdCartera
     AND c.IdControlLegacy = TRY_CONVERT(int, h.HIEC_ID_CONTROL)
    WHERE TRY_CONVERT(int, h.HIEC_ID_REGISTRO) IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM ope.EvolucionCuenta x
          WHERE x.IdCartera = h.__IdCartera
            AND x.IdRegistroLegacy = TRY_CONVERT(int, h.HIEC_ID_REGISTRO)
      );
    PRINT CONCAT('  filas: ', @@ROWCOUNT);
END
GO

-- ---------------------------------------------------------------------------
-- Negociaciones (NENE_NEGOCIACIONES)
-- ---------------------------------------------------------------------------
IF OBJECT_ID('legacy.NENE_NEGOCIACIONES','U') IS NOT NULL
BEGIN
    PRINT 'NENE_NEGOCIACIONES -> ope.Negociacion';
    INSERT INTO ope.Negociacion (
        IdCuenta, IdCartera, IdEmpleado, TipoNegociacion, TipoPago,
        MontoOriginal, PorcentajeDescuento, MontoFinal, NumeroPagos,
        FechaPrimerPago, Comentario, FechaRegistro)
    SELECT
        c.IdCuenta,
        n.__IdCartera,
        ISNULL(ISNULL(emp.IdEmpleadoUnificado, emp.IdEmpleado), 1),
        LEFT(NULLIF(LTRIM(RTRIM(CAST(n.NENE_ID_TIPO_NEGOCIACION AS nvarchar(100)))),''),50),
        LEFT(NULLIF(LTRIM(RTRIM(CAST(n.NENE_LUGAR_PAGO AS nvarchar(100)))),''),50),
        ISNULL(TRY_CONVERT(decimal(18,2), n.NENE_SALDO_NEGOCIACION), 0),
        ISNULL(TRY_CONVERT(decimal(5,2), n.NENE_PORCENTAJE_DESCUENTO), 0),
        ISNULL(TRY_CONVERT(decimal(18,2), n.NENE_MONTO_NEGOCIADO), 0),
        ISNULL(TRY_CONVERT(int, n.NENE_PLAZO), 1),
        TRY_CONVERT(date, n.NENE_FECHA_PRIMER_MENSUALIDAD),
        NULLIF(LTRIM(RTRIM(CAST(n.NENE_EXCEPCION AS nvarchar(max)))), ''),
        ISNULL(TRY_CONVERT(datetime2(0), n.NENE_FECHA_REGISTRO), SYSDATETIME())
    FROM legacy.NENE_NEGOCIACIONES n
    JOIN ope.Cuenta c
      ON c.IdCartera = n.__IdCartera
     AND c.IdControlLegacy = TRY_CONVERT(int, n.NENE_ID_CONTROL)
    LEFT JOIN rh.Empleado emp
      ON emp.IdEmpleado = TRY_CONVERT(int, n.NENE_ID_EMPLEADO)
    WHERE NOT EXISTS (
        SELECT 1 FROM ope.Negociacion x
        WHERE x.IdCartera = n.__IdCartera
          AND x.IdCuenta = c.IdCuenta
          AND ISNULL(x.FechaRegistro,'19000101') = ISNULL(TRY_CONVERT(datetime2(0), n.NENE_FECHA_REGISTRO),'19000101')
          AND ISNULL(x.MontoFinal,0) = ISNULL(TRY_CONVERT(decimal(18,2), n.NENE_MONTO_NEGOCIADO),0)
    );
    PRINT CONCAT('  filas: ', @@ROWCOUNT);
END
GO

-- ---------------------------------------------------------------------------
-- Notas (NENT_NOTAS)
-- ---------------------------------------------------------------------------
IF OBJECT_ID('legacy.NENT_NOTAS','U') IS NOT NULL
BEGIN
    PRINT 'NENT_NOTAS -> ope.Nota';
    INSERT INTO ope.Nota (IdCuenta, IdCartera, IdEmpleado, TipoSeguimiento, FechaSeguimiento, Telefono, Pagos, Importe, Texto, FechaRegistro)
    SELECT
        c.IdCuenta,
        n.__IdCartera,
        ISNULL(ISNULL(emp.IdEmpleadoUnificado, emp.IdEmpleado), 1),
        NULL,
        ISNULL(TRY_CONVERT(datetime2(0), n.NENT_FECHA_REGISTRO), SYSDATETIME()),
        NULL,
        NULL,
        NULL,
        NULLIF(LTRIM(RTRIM(CAST(n.NENT_NOTA AS nvarchar(max)))), ''),
        ISNULL(TRY_CONVERT(datetime2(0), n.NENT_FECHA_REGISTRO), SYSDATETIME())
    FROM legacy.NENT_NOTAS n
    JOIN ope.Cuenta c ON c.IdCartera=n.__IdCartera AND c.IdControlLegacy=TRY_CONVERT(int,n.NENT_ID_CONTROL)
    LEFT JOIN rh.Empleado emp ON emp.IdEmpleado=TRY_CONVERT(int,n.NENT_ID_EMPLEADO)
    WHERE NOT EXISTS (
        SELECT 1 FROM ope.Nota x
        WHERE x.IdCartera=n.__IdCartera AND x.IdCuenta=c.IdCuenta
          AND x.FechaRegistro = ISNULL(TRY_CONVERT(datetime2(0), n.NENT_FECHA_REGISTRO), SYSDATETIME())
          AND ISNULL(CAST(x.Texto AS nvarchar(max)),'') = ISNULL(CAST(n.NENT_NOTA AS nvarchar(max)),'')
    );
    PRINT CONCAT('  filas: ', @@ROWCOUNT);
END
GO

-- ---------------------------------------------------------------------------
-- Bloc de notas (NEBN_BLOC_NOTAS)
-- ---------------------------------------------------------------------------
IF OBJECT_ID('legacy.NEBN_BLOC_NOTAS','U') IS NOT NULL
BEGIN
    PRINT 'NEBN_BLOC_NOTAS -> ope.BlocNota';
    ;WITH src AS (
        SELECT
            b.__IdCartera,
            ISNULL(ISNULL(emp.IdEmpleadoUnificado, emp.IdEmpleado), 1) AS IdEmpleado,
            CAST(b.NEBN_NOTA AS nvarchar(max)) AS Texto,
            ISNULL(TRY_CONVERT(datetime2(0), b.__FechaMigracion), SYSDATETIME()) AS FechaRegistro,
            ROW_NUMBER() OVER (PARTITION BY b.__IdCartera, ISNULL(ISNULL(emp.IdEmpleadoUnificado,emp.IdEmpleado),1)
                               ORDER BY TRY_CONVERT(int,b.NEBN_ID_REGISTRO) DESC) rn
        FROM legacy.NEBN_BLOC_NOTAS b
        LEFT JOIN rh.Empleado emp ON emp.IdEmpleado = TRY_CONVERT(int, b.NEBN_ID_EMPLEADO)
        WHERE 1=1
    )
    MERGE ope.BlocNota AS dst
    USING (SELECT __IdCartera, IdEmpleado, Texto, FechaRegistro FROM src WHERE rn=1) s
      ON dst.IdCartera=s.__IdCartera AND dst.IdEmpleado=s.IdEmpleado
    WHEN MATCHED THEN UPDATE SET Texto=s.Texto, FechaRegistro=s.FechaRegistro
    WHEN NOT MATCHED THEN INSERT (IdCartera, IdEmpleado, Texto, FechaRegistro)
         VALUES (s.__IdCartera, s.IdEmpleado, s.Texto, s.FechaRegistro);
    PRINT CONCAT('  filas afectadas: ', @@ROWCOUNT);
END
GO

PRINT '== Normalización operativa terminada ==';
