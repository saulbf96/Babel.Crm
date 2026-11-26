-- =====================================================================
--  Bajas de personal (reemplaza FRM_BAJAPERSONAL del BABEL ADMINISTRATIVO).
--
--  En BABEL la pantalla estaba ROTA: el combo de causas nunca se llenaba,
--  al limpiar mostraba "MODULO EN CONSTRUCCION" y solo insertaba una
--  "solicitud" en RHALEXA.NEBE_BAJA_EMPLEADO que nadie procesaba.
--
--  Aquí la baja es REAL y LÓGICA (nunca DELETE):
--    rh.Empleado.Activo = 0 + FechaBaja
--    rh.EmpleadoCartera (asignaciones activas) Activo = 0 + FechaBaja
--    seg.Usuario del empleado Activo = 0 (ya no puede entrar)
--  y queda un movimiento auditable en rh.MovimientoBaja (quién, cuándo,
--  causa, comentario). La reactivación también queda registrada.
--
--  Catálogo de causas = RHBABEL.dbo.CACB_CAUSA_BAJA (mismos Id).
--  Idempotente: se puede volver a correr después de una re-migración.
-- =====================================================================
USE BABEL_UNIFICADA;
-- Obligatorio: rh.Empleado y otras tablas tienen índices filtrados (error 1934 si se crean los SP con OFF).
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF OBJECT_ID('rh.CausaBaja') IS NULL
CREATE TABLE rh.CausaBaja (
    IdCausaBaja tinyint      NOT NULL PRIMARY KEY,
    Nombre      varchar(150) NOT NULL,
    Activo      bit          NOT NULL CONSTRAINT DF_CausaBaja_Activo DEFAULT (1),
    CONSTRAINT UQ_CausaBaja_Nombre UNIQUE (Nombre)
);
GO

-- Causas de BABEL (RHBABEL.dbo.CACB_CAUSA_BAJA), mismos Id.
MERGE rh.CausaBaja AS d
USING (VALUES
    (1, 'FALTAS'),
    (2, 'ACTITUD'),
    (3, 'BAJA PRODUCTIVIDAD'),
    (4, 'CARTAS ADMINISTRATIVAS'),
    (5, 'ACOSO')
) AS o (IdCausaBaja, Nombre)
ON d.IdCausaBaja = o.IdCausaBaja
WHEN NOT MATCHED THEN INSERT (IdCausaBaja, Nombre) VALUES (o.IdCausaBaja, o.Nombre);
GO

IF OBJECT_ID('rh.MovimientoBaja') IS NULL
CREATE TABLE rh.MovimientoBaja (
    IdMovimiento    int           NOT NULL IDENTITY(1,1) PRIMARY KEY,
    IdEmpleado      int           NOT NULL,
    Tipo            char(1)       NOT NULL,      -- B = baja, R = reactivación
    IdCausaBaja     tinyint       NULL,          -- solo en bajas
    Comentario      varchar(500)  NOT NULL,
    FechaEfectiva   date          NOT NULL,      -- último día laborado / día de reingreso
    IdCartera       tinyint       NOT NULL,      -- cartera del admin que lo hizo
    UsuarioRegistro varchar(50)   NOT NULL,
    FechaRegistro   datetime2(0)  NOT NULL CONSTRAINT DF_MovimientoBaja_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT CK_MovimientoBaja_Tipo  CHECK (Tipo IN ('B', 'R')),
    CONSTRAINT CK_MovimientoBaja_Causa CHECK ((Tipo = 'B' AND IdCausaBaja IS NOT NULL) OR (Tipo = 'R' AND IdCausaBaja IS NULL)),
    CONSTRAINT FK_MovimientoBaja_Empleado FOREIGN KEY (IdEmpleado)  REFERENCES rh.Empleado (IdEmpleado),
    CONSTRAINT FK_MovimientoBaja_Causa    FOREIGN KEY (IdCausaBaja) REFERENCES rh.CausaBaja (IdCausaBaja)
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_MovimientoBaja_Empleado')
    CREATE INDEX IX_MovimientoBaja_Empleado ON rh.MovimientoBaja (IdEmpleado, IdMovimiento DESC);
GO

-- Cuentas por asesor dentro de una cartera (Bajas, baja de empleado, reasignación).
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Cuenta_Cartera_Empleado' AND object_id = OBJECT_ID('ope.Cuenta'))
    CREATE INDEX IX_Cuenta_Cartera_Empleado ON ope.Cuenta (IdCartera, IdEmpleado) INCLUDE (Activo);
GO

-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE rh.USP_CONSULTA_CAUSAS_BAJA
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdCausaBaja, Nombre FROM rh.CausaBaja WHERE Activo = 1 ORDER BY Nombre;
END
GO

-- ---------------------------------------------------------------------
--  Empleados de la cartera (activos y dados de baja) con su última baja
--  y cuántas cuentas tiene asignadas (hay que reasignarlas al darlo de baja).
--  @Estatus: 'A' activos, 'B' dados de baja, 'T' todos.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE rh.USP_CONSULTA_BAJAS
    @IdCartera tinyint,
    @Nombre    varchar(100) = NULL,
    @Estatus   char(1)      = 'A'
AS
BEGIN
    SET NOCOUNT ON;
    SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), '');

    SELECT TOP (5000)   -- la pantalla pagina (25/50/100 por página)
        e.IdEmpleado,
        LTRIM(RTRIM(CONCAT(e.Nombre, ' ', e.Paterno, ' ', ISNULL(e.Materno, '')))) AS NombreCompleto,
        u.Usuario,
        p.Nombre AS Puesto,
        e.FechaIngreso,
        e.Activo,
        CAST(e.FechaBaja AS date) AS FechaBaja,
        cb.Nombre AS CausaBaja,
        mb.Comentario AS ComentarioBaja,
        mb.UsuarioRegistro AS UsuarioBaja,
        mb.FechaRegistro AS FechaRegistroBaja,   -- cuándo se capturó la baja (con hora)
        ISNULL(cu.Cuentas, 0) AS CuentasAsignadas
    FROM rh.Empleado e
    INNER JOIN rh.Puesto p ON p.IdPuesto = e.IdPuesto
    LEFT JOIN seg.Usuario u ON u.IdEmpleado = e.IdEmpleado
    OUTER APPLY (
        SELECT TOP 1 m.IdCausaBaja, m.Comentario, m.UsuarioRegistro, m.FechaRegistro
        FROM rh.MovimientoBaja m
        WHERE m.IdEmpleado = e.IdEmpleado AND m.Tipo = 'B' AND e.Activo = 0
        ORDER BY m.IdMovimiento DESC
    ) mb
    LEFT JOIN rh.CausaBaja cb ON cb.IdCausaBaja = mb.IdCausaBaja
    -- Cuentas ACTIVAS asignadas, contadas una sola vez por cartera (antes: una búsqueda por
    -- empleado sobre toda la cartera = 15 s con 1.8 M de cuentas). Usa IX_Cuenta_Cartera_Empleado.
    LEFT JOIN (
        SELECT c.IdEmpleado, COUNT(*) AS Cuentas
        FROM ope.Cuenta c
        WHERE c.IdCartera = @IdCartera AND c.Activo = 1 AND c.IdEmpleado IS NOT NULL
        GROUP BY c.IdEmpleado
    ) cu ON cu.IdEmpleado = e.IdEmpleado
    WHERE e.IdEmpleadoUnificado IS NULL   -- registros repetidos ya unificados: no son bajas reales
      AND EXISTS (
            -- Pertenece (o pertenecía, si está de baja) a la cartera del admin.
            SELECT 1 FROM rh.EmpleadoCartera ec
            WHERE ec.IdEmpleado = e.IdEmpleado AND ec.IdCartera = @IdCartera
              AND (ec.Activo = 1 OR e.Activo = 0))
      AND (@Estatus = 'T' OR (@Estatus = 'A' AND e.Activo = 1) OR (@Estatus = 'B' AND e.Activo = 0))
      AND (@Nombre IS NULL
           OR CONCAT(e.Nombre, ' ', e.Paterno, ' ', ISNULL(e.Materno, '')) LIKE '%' + @Nombre + '%'
           OR u.Usuario LIKE '%' + @Nombre + '%'
           OR CAST(e.IdEmpleado AS varchar(10)) = @Nombre)
    ORDER BY e.Activo DESC, e.Paterno, e.Materno, e.Nombre;
END
GO

-- ---------------------------------------------------------------------
--  Baja lógica del empleado + sus asignaciones + su usuario, en una sola
--  transacción. Las reglas se validan aquí (además del backend).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE rh.USP_BAJA_EMPLEADO
    @IdEmpleado      int,
    @IdCartera       tinyint,
    @IdCausaBaja     tinyint,
    @Comentario      varchar(500),
    @FechaBaja       date,
    @IdUsuarioActual int,
    @Usuario         varchar(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Ingreso date, @Activo bit;
    SELECT @Ingreso = FechaIngreso, @Activo = Activo FROM rh.Empleado WHERE IdEmpleado = @IdEmpleado;

    IF @Activo IS NULL
        OR NOT EXISTS (SELECT 1 FROM rh.EmpleadoCartera
                       WHERE IdEmpleado = @IdEmpleado AND IdCartera = @IdCartera
                         AND (Activo = 1 OR @Activo = 0))   -- si ya está de baja, su asignación quedó cerrada
        THROW 50001, 'El empleado no existe o no pertenece a tu cartera.', 1;
    IF @Activo = 0
        THROW 50002, 'El empleado ya está dado de baja.', 1;
    IF EXISTS (SELECT 1 FROM seg.Usuario WHERE IdUsuario = @IdUsuarioActual AND IdEmpleado = @IdEmpleado)
        THROW 50003, 'No puedes darte de baja a ti mismo.', 1;
    IF NOT EXISTS (SELECT 1 FROM rh.CausaBaja WHERE IdCausaBaja = @IdCausaBaja AND Activo = 1)
        THROW 50004, 'Selecciona una causa de baja válida.', 1;
    -- La baja es SIEMPRE con fecha de hoy (no se dan de baja fechas pasadas ni futuras).
    -- @FechaBaja se conserva en la firma por compatibilidad, pero se ignora.
    SET @FechaBaja = CAST(SYSDATETIME() AS date);
    IF @FechaBaja < @Ingreso
        THROW 50006, 'La fecha de baja no puede ser anterior a la fecha de ingreso.', 1;

    DECLARE @Momento datetime2(0) = CAST(@FechaBaja AS datetime2(0));

    BEGIN TRAN;

    INSERT INTO rh.MovimientoBaja (IdEmpleado, Tipo, IdCausaBaja, Comentario, FechaEfectiva, IdCartera, UsuarioRegistro)
    VALUES (@IdEmpleado, 'B', @IdCausaBaja, @Comentario, @FechaBaja, @IdCartera, @Usuario);

    UPDATE rh.Empleado
       SET Activo = 0, FechaBaja = @Momento
     WHERE IdEmpleado = @IdEmpleado;

    UPDATE rh.EmpleadoCartera
       SET Activo = 0, FechaBaja = @Momento
     WHERE IdEmpleado = @IdEmpleado AND Activo = 1;

    UPDATE seg.Usuario
       SET Activo = 0
     WHERE IdEmpleado = @IdEmpleado;

    COMMIT;

    SELECT
        (SELECT COUNT(*) FROM ope.Cuenta WHERE IdCartera = @IdCartera AND IdEmpleado = @IdEmpleado) AS CuentasAsignadas,
        (SELECT COUNT(*) FROM seg.Usuario WHERE IdEmpleado = @IdEmpleado) AS UsuariosDesactivados;
END
GO

-- ---------------------------------------------------------------------
--  Reactivación (baja por error o reingreso). Restaura las asignaciones
--  que cerró la última baja y reactiva el usuario con cambio de contraseña
--  obligatorio (vuelve después de un tiempo fuera).
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE rh.USP_REACTIVAR_EMPLEADO
    @IdEmpleado int,
    @IdCartera  tinyint,
    @Comentario varchar(500),
    @Usuario    varchar(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Activo bit, @FechaBaja datetime2(0);
    SELECT @Activo = Activo, @FechaBaja = FechaBaja FROM rh.Empleado WHERE IdEmpleado = @IdEmpleado;

    IF @Activo IS NULL
        OR NOT EXISTS (SELECT 1 FROM rh.EmpleadoCartera WHERE IdEmpleado = @IdEmpleado AND IdCartera = @IdCartera)
        THROW 50001, 'El empleado no existe o no pertenece a tu cartera.', 1;
    IF @Activo = 1
        THROW 50007, 'El empleado ya está activo.', 1;
    IF EXISTS (SELECT 1 FROM rh.Empleado WHERE IdEmpleado = @IdEmpleado AND IdEmpleadoUnificado IS NOT NULL)
        THROW 50008, 'Este registro se unificó con otro empleado de la misma persona; reactiva ese.', 1;

    BEGIN TRAN;

    INSERT INTO rh.MovimientoBaja (IdEmpleado, Tipo, IdCausaBaja, Comentario, FechaEfectiva, IdCartera, UsuarioRegistro)
    VALUES (@IdEmpleado, 'R', NULL, @Comentario, CAST(SYSDATETIME() AS date), @IdCartera, @Usuario);

    UPDATE rh.Empleado
       SET Activo = 1, FechaBaja = NULL
     WHERE IdEmpleado = @IdEmpleado;

    -- Solo las asignaciones que cerró la baja (misma fecha de baja).
    UPDATE rh.EmpleadoCartera
       SET Activo = 1, FechaBaja = NULL
     WHERE IdEmpleado = @IdEmpleado AND Activo = 0 AND FechaBaja = @FechaBaja;

    UPDATE seg.Usuario
       SET Activo = 1, DebeCambiarContrasena = 1
     WHERE IdEmpleado = @IdEmpleado;

    COMMIT;
END
GO
