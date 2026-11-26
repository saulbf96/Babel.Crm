/*
  BABEL_UNIFICADA - 05. Carteras, cambio de cartera y asignacion de personal.

  Equivale a:
    - FRM_CONSULTA_BASE        -> cart.USP_CONSULTA_CARTERAS / cart.USP_VALIDA_CARTERA
    - FRM_ASIGNARPERSONAL      -> cart.USP_CONSULTA_PERSONAL / cart.USP_ASIGNA_PERSONAL /
                                  cart.USP_RESTAURA_PERSONAL / cart.USP_CONSULTA_OPERATIVO

  En el .exe, "Cambia Cartera" solo cambiaba la base activa de la sesion
  (MDL_INICIO.ID_BBDD); no escribia en la base. Aqui la sesion se guarda en la
  cookie del CRM y el endpoint reemite la cookie con la nueva cartera.

  "Asignar personal" en el .exe movia al empleado con ACTUALIZA_AGENTE_BASE y,
  si se marcaba operativo, lo registraba en TRAO_AGENTE_OPERATIVO. Aqui se hace
  lo mismo con rh.EmpleadoCartera y ope.AgenteOperativo.
*/
USE BABEL_UNIFICADA;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- ---------- Personal en operativo (TRAO_AGENTE_OPERATIVO) ----------
IF OBJECT_ID('ope.AgenteOperativo') IS NULL
CREATE TABLE ope.AgenteOperativo (
    IdRegistro    int          NOT NULL IDENTITY(1,1) PRIMARY KEY,
    IdEmpleado    int          NOT NULL,
    IdAreaDep     tinyint      NOT NULL,
    IdCartera     tinyint      NOT NULL,
    IdSegmento    tinyint      NOT NULL CONSTRAINT DF_AgenteOperativo_Segmento DEFAULT (0),
    IdProducto    tinyint      NOT NULL CONSTRAINT DF_AgenteOperativo_Producto DEFAULT (0),
    IdCampana     tinyint      NOT NULL CONSTRAINT DF_AgenteOperativo_Campana  DEFAULT (0),
    Activo        bit          NOT NULL CONSTRAINT DF_AgenteOperativo_Activo DEFAULT (1),
    FechaRegistro datetime2(0) NOT NULL CONSTRAINT DF_AgenteOperativo_Fecha DEFAULT (SYSDATETIME()),
    FechaBaja     datetime2(0) NULL,
    CONSTRAINT FK_AgenteOperativo_Empleado FOREIGN KEY (IdEmpleado) REFERENCES rh.Empleado (IdEmpleado),
    CONSTRAINT FK_AgenteOperativo_Cartera  FOREIGN KEY (IdCartera)  REFERENCES cart.Cartera (IdCartera),
    CONSTRAINT FK_AgenteOperativo_Area     FOREIGN KEY (IdAreaDep)  REFERENCES rh.Departamento (IdDepartamento)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_AgenteOperativo_Activo' AND object_id = OBJECT_ID('ope.AgenteOperativo'))
    CREATE UNIQUE INDEX UX_AgenteOperativo_Activo ON ope.AgenteOperativo (IdEmpleado) WHERE Activo = 1;
GO

-- =====================================================================
--  Carteras visibles para el usuario
--  - Perfiles administrativos (1,5,8,26,27): todas las carteras activas.
--  - Demas: carteras de acceso explicito (EmpleadoCarteraAcceso) o su
--    cartera activa (EmpleadoCartera).
-- =====================================================================
CREATE OR ALTER PROCEDURE cart.USP_CONSULTA_CARTERAS
    @IdUsuario int = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdPuesto tinyint, @IdEmpleado int;

    IF @IdUsuario IS NOT NULL
        SELECT @IdPuesto = IdPuesto, @IdEmpleado = IdEmpleado
        FROM seg.Usuario
        WHERE IdUsuario = @IdUsuario AND Activo = 1;

    IF @IdUsuario IS NULL OR @IdPuesto IN (1, 5, 8, 26, 27)
    BEGIN
        SELECT c.IdCartera, c.Nombre, c.IdCliente, cl.Nombre AS Cliente,
               c.IdBaseLegacy, c.IdDepartamento, c.Activo
        FROM cart.Cartera c
        INNER JOIN cart.Cliente cl ON cl.IdCliente = c.IdCliente
        WHERE c.Activo = 1
        ORDER BY c.IdCartera;
        RETURN;
    END

    IF @IdEmpleado IS NULL
    BEGIN
        SELECT TOP 0 c.IdCartera, c.Nombre, c.IdCliente, cl.Nombre AS Cliente,
               c.IdBaseLegacy, c.IdDepartamento, c.Activo
        FROM cart.Cartera c
        INNER JOIN cart.Cliente cl ON cl.IdCliente = c.IdCliente;
        RETURN;
    END

    SELECT c.IdCartera, c.Nombre, c.IdCliente, cl.Nombre AS Cliente,
           c.IdBaseLegacy, c.IdDepartamento, c.Activo
    FROM cart.Cartera c
    INNER JOIN cart.Cliente cl ON cl.IdCliente = c.IdCliente
    WHERE c.Activo = 1
      AND c.IdCartera IN (
            SELECT IdCartera FROM rh.EmpleadoCarteraAcceso WHERE IdEmpleado = @IdEmpleado AND Activo = 1
            UNION
            SELECT IdCartera FROM rh.EmpleadoCartera       WHERE IdEmpleado = @IdEmpleado AND Activo = 1)
    ORDER BY c.IdCartera;
END
GO

CREATE OR ALTER PROCEDURE cart.USP_VALIDA_CARTERA
    @IdUsuario int,
    @IdCartera tinyint
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdPuesto tinyint, @IdEmpleado int;

    SELECT @IdPuesto = IdPuesto, @IdEmpleado = IdEmpleado
    FROM seg.Usuario
    WHERE IdUsuario = @IdUsuario AND Activo = 1;

    IF @IdPuesto IN (1, 5, 8, 26, 27)
    BEGIN
        SELECT c.IdCartera, c.Nombre, c.IdCliente, cl.Nombre AS Cliente,
               c.IdBaseLegacy, c.IdDepartamento, CAST(1 AS bit) AS Permitida
        FROM cart.Cartera c
        INNER JOIN cart.Cliente cl ON cl.IdCliente = c.IdCliente
        WHERE c.IdCartera = @IdCartera AND c.Activo = 1;
        RETURN;
    END

    SELECT c.IdCartera, c.Nombre, c.IdCliente, cl.Nombre AS Cliente,
           c.IdBaseLegacy, c.IdDepartamento, CAST(1 AS bit) AS Permitida
    FROM cart.Cartera c
    INNER JOIN cart.Cliente cl ON cl.IdCliente = c.IdCliente
    WHERE c.IdCartera = @IdCartera AND c.Activo = 1
      AND @IdEmpleado IS NOT NULL
      AND (EXISTS (SELECT 1 FROM rh.EmpleadoCarteraAcceso a WHERE a.IdEmpleado = @IdEmpleado AND a.IdCartera = c.IdCartera AND a.Activo = 1)
           OR EXISTS (SELECT 1 FROM rh.EmpleadoCartera e WHERE e.IdEmpleado = @IdEmpleado AND e.IdCartera = c.IdCartera AND e.Activo = 1));
END
GO

-- =====================================================================
--  Personal para la pantalla "Asignar personal a cartera"
--  Devuelve a todos los empleados activos con dos banderas:
--    Asignado  = su cartera activa es @IdCartera
--    Operativo = esta en operativo de @IdCartera
--  Asi el administrador puede ver tanto los ya asignados como los nuevos.
-- =====================================================================
CREATE OR ALTER PROCEDURE cart.USP_CONSULTA_PERSONAL
    @IdCartera tinyint,
    @Texto     varchar(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @Texto = NULLIF(LTRIM(RTRIM(@Texto)), '');

    SELECT
        e.IdEmpleado,
        LTRIM(RTRIM(CONCAT(e.Nombre, ' ', e.Paterno, ' ', ISNULL(e.Materno, '')))) AS NombreCompleto,
        e.IdPuesto,
        p.Nombre AS Puesto,
        e.IdDepartamento,
        d.Nombre AS Departamento,
        ec.IdCartera,
        c.Nombre AS Cartera,
        CAST(CASE WHEN ec.IdCartera = @IdCartera THEN 1 ELSE 0 END AS bit) AS Asignado,
        CAST(CASE WHEN op.IdRegistro IS NOT NULL THEN 1 ELSE 0 END AS bit) AS Operativo,
        ISNULL(op.IdAreaDep, ISNULL(ec.IdDepartamento, e.IdDepartamento)) AS IdAreaDep,
        ISNULL(op.IdSegmento, ISNULL(ec.IdSegmento, 0)) AS IdSegmento,
        ISNULL(op.IdProducto, ISNULL(ec.IdProducto, 0)) AS IdProducto,
        ISNULL(op.IdCampana,  ISNULL(ec.IdCampana, 0))  AS IdCampana
    FROM rh.Empleado e
    INNER JOIN rh.Puesto       p ON p.IdPuesto       = e.IdPuesto
    INNER JOIN rh.Departamento d ON d.IdDepartamento = e.IdDepartamento
    OUTER APPLY (
        SELECT TOP 1 x.IdCartera, x.IdDepartamento, x.IdSegmento, x.IdProducto, x.IdCampana
        FROM rh.EmpleadoCartera x
        WHERE x.IdEmpleado = e.IdEmpleado AND x.Activo = 1
        ORDER BY x.IdEmpleadoCartera DESC
    ) ec
    LEFT JOIN cart.Cartera c ON c.IdCartera = ec.IdCartera
    OUTER APPLY (
        SELECT TOP 1 o.IdRegistro, o.IdAreaDep, o.IdSegmento, o.IdProducto, o.IdCampana
        FROM ope.AgenteOperativo o
        WHERE o.IdEmpleado = e.IdEmpleado AND o.IdCartera = @IdCartera AND o.Activo = 1
        ORDER BY o.IdRegistro DESC
    ) op
    WHERE e.Activo = 1
      AND (@Texto IS NULL
           OR e.Nombre LIKE '%' + @Texto + '%'
           OR e.Paterno LIKE '%' + @Texto + '%'
           OR ISNULL(e.Materno, '') LIKE '%' + @Texto + '%'
           OR CONCAT(e.Nombre, ' ', e.Paterno, ' ', ISNULL(e.Materno, '')) LIKE '%' + @Texto + '%')
    ORDER BY e.Paterno, e.Materno, e.Nombre;
END
GO

-- =====================================================================
--  Asignar / mover personal a una cartera
--  @IdsEmpleados: lista separada por comas, igual que el .exe.
--  @Operativo = 1: ademas lo registra en ope.AgenteOperativo.
-- =====================================================================
CREATE OR ALTER PROCEDURE cart.USP_ASIGNA_PERSONAL
    @IdsEmpleados   varchar(max),
    @IdCartera      tinyint,
    @IdDepartamento tinyint = NULL,
    @Operativo      bit = 0,
    @Usuario        varchar(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM cart.Cartera WHERE IdCartera = @IdCartera AND Activo = 1)
        THROW 50010, 'La cartera seleccionada no existe o esta inactiva.', 1;

    DECLARE @Depto tinyint = NULLIF(@IdDepartamento, 0);
    IF @Depto IS NULL
        SET @Depto = ISNULL((SELECT IdDepartamento FROM cart.Cartera WHERE IdCartera = @IdCartera), 12);

    DECLARE @Ids TABLE (IdEmpleado int NOT NULL PRIMARY KEY);
    INSERT INTO @Ids (IdEmpleado)
    SELECT DISTINCT TRY_CAST(value AS int)
    FROM STRING_SPLIT(@IdsEmpleados, ',')
    WHERE TRY_CAST(value AS int) IS NOT NULL;

    IF NOT EXISTS (SELECT 1 FROM @Ids)
        THROW 50011, 'No se recibio ningun empleado para asignar.', 1;

    DECLARE @Validos TABLE (IdEmpleado int NOT NULL PRIMARY KEY);
    INSERT INTO @Validos (IdEmpleado)
    SELECT i.IdEmpleado
    FROM @Ids i
    WHERE EXISTS (SELECT 1 FROM rh.Empleado e WHERE e.IdEmpleado = i.IdEmpleado AND e.Activo = 1);

    DECLARE @Asignados int = (SELECT COUNT(*) FROM @Validos);
    DECLARE @Omitidos  int = (SELECT COUNT(*) FROM @Ids) - @Asignados;

    IF @Asignados = 0
        THROW 50012, 'Ninguno de los empleados recibidos esta activo.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Cerrar la asignacion anterior (el .exe mueve, no duplica).
        UPDATE ec
           SET Activo = 0, FechaBaja = SYSDATETIME()
        FROM rh.EmpleadoCartera ec
        INNER JOIN @Validos v ON v.IdEmpleado = ec.IdEmpleado
        WHERE ec.Activo = 1;

        -- 2. Nueva cartera activa.
        INSERT INTO rh.EmpleadoCartera (IdEmpleado, IdCartera, IdDepartamento, Activo)
        SELECT v.IdEmpleado, @IdCartera, @Depto, 1
        FROM @Validos v;

        -- 3. Acceso a la cartera para "Cambia Cartera".
        UPDATE a
           SET Activo = 1
        FROM rh.EmpleadoCarteraAcceso a
        INNER JOIN @Validos v ON v.IdEmpleado = a.IdEmpleado
        WHERE a.IdCartera = @IdCartera;

        INSERT INTO rh.EmpleadoCarteraAcceso (IdEmpleado, IdCartera, Activo)
        SELECT v.IdEmpleado, @IdCartera, 1
        FROM @Validos v
        WHERE NOT EXISTS (
            SELECT 1 FROM rh.EmpleadoCarteraAcceso a
            WHERE a.IdEmpleado = v.IdEmpleado AND a.IdCartera = @IdCartera);

        -- 4. El departamento del empleado sigue a la cartera (como ACTUALIZA_AGENTE_BASE).
        UPDATE e
           SET IdDepartamento = @Depto
        FROM rh.Empleado e
        INNER JOIN @Validos v ON v.IdEmpleado = e.IdEmpleado;

        -- 5. Operativo: mover al empleado a la nueva cartera operativa.
        IF @Operativo = 1
        BEGIN
            UPDATE op
               SET Activo = 0, FechaBaja = SYSDATETIME()
            FROM ope.AgenteOperativo op
            INNER JOIN @Validos v ON v.IdEmpleado = op.IdEmpleado
            WHERE op.Activo = 1;

            INSERT INTO ope.AgenteOperativo (IdEmpleado, IdAreaDep, IdCartera, Activo)
            SELECT v.IdEmpleado, @Depto, @IdCartera, 1
            FROM @Validos v;
        END

        INSERT INTO log.Auditoria (Usuario, Accion, Entidad, IdEntidad, Detalle)
        VALUES (@Usuario,
                CASE WHEN @Operativo = 1 THEN 'ASIGNA_OPERATIVO' ELSE 'ASIGNA_CARTERA' END,
                'cart.Cartera', CAST(@IdCartera AS varchar(20)),
                CONCAT('Asignados: ', @Asignados, '; omitidos: ', @Omitidos,
                       '; operativo: ', CASE WHEN @Operativo = 1 THEN 'si' ELSE 'no' END));

        COMMIT TRANSACTION;

        SELECT @Asignados AS Asignados, @Omitidos AS Omitidos,
               CASE WHEN @Operativo = 1 THEN 'Personal asignado a operativo.'
                    ELSE 'Personal asignado a nueva cartera.' END AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- =====================================================================
--  Restaurar personal que estaba en un operativo
-- =====================================================================
CREATE OR ALTER PROCEDURE cart.USP_RESTAURA_PERSONAL
    @IdsEmpleados varchar(max),
    @Usuario      varchar(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Ids TABLE (IdEmpleado int NOT NULL PRIMARY KEY);
    INSERT INTO @Ids (IdEmpleado)
    SELECT DISTINCT TRY_CAST(value AS int)
    FROM STRING_SPLIT(@IdsEmpleados, ',')
    WHERE TRY_CAST(value AS int) IS NOT NULL;

    DECLARE @Restaurados int = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE op
           SET Activo = 0, FechaBaja = SYSDATETIME()
        FROM ope.AgenteOperativo op
        INNER JOIN @Ids i ON i.IdEmpleado = op.IdEmpleado
        WHERE op.Activo = 1;

        SET @Restaurados = @@ROWCOUNT;

        INSERT INTO log.Auditoria (Usuario, Accion, Entidad, Detalle)
        VALUES (@Usuario, 'RESTAURA_OPERATIVO', 'ope.AgenteOperativo',
                CONCAT('Restaurados: ', @Restaurados));

        COMMIT TRANSACTION;

        SELECT @Restaurados AS Restaurados,
               CASE WHEN @Restaurados = 0 THEN 'No habia personal operativo que restaurar.'
                    ELSE 'Personal restaurado.' END AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE cart.USP_CONSULTA_OPERATIVO
    @IdEmpleado int = NULL,
    @IdCartera  tinyint = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        o.IdRegistro,
        o.IdEmpleado,
        LTRIM(RTRIM(CONCAT(e.Nombre, ' ', e.Paterno, ' ', ISNULL(e.Materno, '')))) AS NombreCompleto,
        o.IdAreaDep,
        d.Nombre AS Area,
        o.IdCartera,
        c.Nombre AS Cartera,
        o.IdSegmento,
        o.IdProducto,
        o.IdCampana,
        o.FechaRegistro
    FROM ope.AgenteOperativo o
    INNER JOIN rh.Empleado     e ON e.IdEmpleado = o.IdEmpleado
    INNER JOIN rh.Departamento d ON d.IdDepartamento = o.IdAreaDep
    INNER JOIN cart.Cartera    c ON c.IdCartera = o.IdCartera
    WHERE o.Activo = 1
      AND (@IdEmpleado IS NULL OR o.IdEmpleado = @IdEmpleado)
      AND (@IdCartera  IS NULL OR o.IdCartera  = @IdCartera)
    ORDER BY e.Paterno, e.Materno, e.Nombre;
END
GO

CREATE OR ALTER PROCEDURE cart.USP_CONSULTA_CLIENTES
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdCliente, Nombre FROM cart.Cliente WHERE Activo = 1 ORDER BY IdCliente;
END
GO

PRINT 'Modulo cart listo (carteras, cambio de cartera, asignacion y operativo).';
GO
