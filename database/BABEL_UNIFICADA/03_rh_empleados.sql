/*
  BABEL_UNIFICADA - 03. Modulo RH: empleados, asignacion a cartera y SPs de alta/consulta.

  Equivale a las pantallas del .exe:
    - FRM_CONSULTAEMPLEADOS  -> rh.USP_CONSULTA_EMPLEADOS
    - FRM_ALTAEMPLEADOS      -> rh.USP_ALTA_EMPLEADO

  Origen del diseno: RHBABEL.NEEM_EMPLEADO, CAPU_PUESTO, CADP_DEPARTAMENTO,
  CASX_SEXO, CATR_TURNO y CONFIGURACION_APP.RECE_CLIENTE_EMPLEADO.

  Diferencias deliberadas con el .exe:
    - Una sola tabla de empleados (no una por base).
    - La cartera se guarda en rh.EmpleadoCartera con IdCartera.
    - El sexo se normaliza a 1=Masculino, 2=Femenino, 3=Otro.
    - No se migran contrasenas en claro: el login vive en seg.Usuario con PBKDF2.
*/
USE BABEL_UNIFICADA;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- ---------- Empleados ----------
IF OBJECT_ID('rh.Empleado') IS NULL
CREATE TABLE rh.Empleado (
    IdEmpleado       int           NOT NULL IDENTITY(1,1) PRIMARY KEY,
    IdEmpleadoLegacy int           NULL,   -- NEEM_ID_EMPLEADO del .exe, para migracion
    Nombre           varchar(100)  NOT NULL,
    Paterno          varchar(100)  NOT NULL,
    Materno          varchar(100)  NULL,
    IdPuesto         tinyint       NOT NULL,
    IdDepartamento   tinyint       NOT NULL,
    IdSexo           tinyint       NOT NULL,
    IdTurno          tinyint       NOT NULL,
    FechaNacimiento  date          NULL,
    FechaIngreso     date          NOT NULL CONSTRAINT DF_Empleado_FechaIngreso DEFAULT (CONVERT(date, GETDATE())),
    Rfc              varchar(13)   NULL,
    Curp             varchar(18)   NULL,
    Nss              bigint        NULL,
    Email            varchar(150)  NULL,
    Activo           bit           NOT NULL CONSTRAINT DF_Empleado_Activo DEFAULT (1),
    FechaRegistro    datetime2(0)  NOT NULL CONSTRAINT DF_Empleado_FechaRegistro DEFAULT (SYSDATETIME()),
    FechaBaja        datetime2(0)  NULL,
    CONSTRAINT FK_Empleado_Puesto       FOREIGN KEY (IdPuesto)       REFERENCES rh.Puesto (IdPuesto),
    CONSTRAINT FK_Empleado_Departamento FOREIGN KEY (IdDepartamento) REFERENCES rh.Departamento (IdDepartamento),
    CONSTRAINT FK_Empleado_Sexo         FOREIGN KEY (IdSexo)         REFERENCES cat.Sexo (IdSexo),
    CONSTRAINT FK_Empleado_Turno        FOREIGN KEY (IdTurno)        REFERENCES cat.Turno (IdTurno)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_Empleado_Legacy' AND object_id = OBJECT_ID('rh.Empleado'))
    CREATE UNIQUE INDEX UX_Empleado_Legacy ON rh.Empleado (IdEmpleadoLegacy) WHERE IdEmpleadoLegacy IS NOT NULL;
GO

-- ---------- Asignacion del empleado a una cartera ----------
-- Un empleado tiene UNA cartera activa (el .exe lo "mueve" con ACTUALIZA_AGENTE_BASE).
IF OBJECT_ID('rh.EmpleadoCartera') IS NULL
CREATE TABLE rh.EmpleadoCartera (
    IdEmpleadoCartera int           NOT NULL IDENTITY(1,1) PRIMARY KEY,
    IdEmpleado        int           NOT NULL,
    IdCartera         tinyint       NOT NULL,
    IdDepartamento    tinyint       NOT NULL,
    IdSegmento        tinyint       NOT NULL CONSTRAINT DF_EmpleadoCartera_Segmento DEFAULT (0),
    IdProducto        tinyint       NOT NULL CONSTRAINT DF_EmpleadoCartera_Producto DEFAULT (0),
    IdCampana         tinyint       NOT NULL CONSTRAINT DF_EmpleadoCartera_Campana  DEFAULT (0),
    Activo            bit           NOT NULL CONSTRAINT DF_EmpleadoCartera_Activo DEFAULT (1),
    FechaRegistro     datetime2(0)  NOT NULL CONSTRAINT DF_EmpleadoCartera_Fecha DEFAULT (SYSDATETIME()),
    FechaBaja         datetime2(0)  NULL,
    IdRegistroLegacy  smallint      NULL,   -- RECE_ID_GCL_EMPL del .exe
    CONSTRAINT FK_EmpleadoCartera_Empleado     FOREIGN KEY (IdEmpleado)     REFERENCES rh.Empleado (IdEmpleado),
    CONSTRAINT FK_EmpleadoCartera_Cartera      FOREIGN KEY (IdCartera)      REFERENCES cart.Cartera (IdCartera),
    CONSTRAINT FK_EmpleadoCartera_Departamento FOREIGN KEY (IdDepartamento) REFERENCES rh.Departamento (IdDepartamento)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_EmpleadoCartera_Activa' AND object_id = OBJECT_ID('rh.EmpleadoCartera'))
    CREATE UNIQUE INDEX UX_EmpleadoCartera_Activa ON rh.EmpleadoCartera (IdEmpleado) WHERE Activo = 1;
GO

-- ---------- Carteras a las que puede entrar el empleado ----------
-- Equivale a CONFIGURACION_APP.REUM_USUARIO_MULTI_CARTERA.
-- Si un empleado no tiene filas aqui, se usa su cartera activa.
IF OBJECT_ID('rh.EmpleadoCarteraAcceso') IS NULL
CREATE TABLE rh.EmpleadoCarteraAcceso (
    IdAcceso      int          NOT NULL IDENTITY(1,1) PRIMARY KEY,
    IdEmpleado    int          NOT NULL,
    IdCartera     tinyint      NOT NULL,
    Activo        bit          NOT NULL CONSTRAINT DF_EmpleadoCarteraAcceso_Activo DEFAULT (1),
    FechaRegistro datetime2(0) NOT NULL CONSTRAINT DF_EmpleadoCarteraAcceso_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT FK_EmpleadoCarteraAcceso_Empleado FOREIGN KEY (IdEmpleado) REFERENCES rh.Empleado (IdEmpleado),
    CONSTRAINT FK_EmpleadoCarteraAcceso_Cartera  FOREIGN KEY (IdCartera)  REFERENCES cart.Cartera (IdCartera),
    CONSTRAINT UQ_EmpleadoCarteraAcceso UNIQUE (IdEmpleado, IdCartera)
);
GO

-- =====================================================================
--  Consulta de empleados (paridad con FRM_CONSULTAEMPLEADOS)
-- =====================================================================
CREATE OR ALTER PROCEDURE rh.USP_CONSULTA_EMPLEADOS
    @Nombre    varchar(100) = NULL,
    @IdPuesto  tinyint      = NULL,
    @IdCartera tinyint      = NULL,
    @SoloActivos bit        = 1
AS
BEGIN
    SET NOCOUNT ON;

    SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), '');

    SELECT
        e.IdEmpleado,
        e.Nombre,
        e.Paterno,
        e.Materno,
        LTRIM(RTRIM(CONCAT(e.Nombre, ' ', e.Paterno, ' ', ISNULL(e.Materno, '')))) AS NombreCompleto,
        u.Usuario,
        e.IdPuesto,
        p.Nombre AS Puesto,
        e.IdDepartamento,
        d.Nombre AS Departamento,
        ec.IdCartera,
        c.Nombre AS Cartera,
        e.IdSexo,
        s.Nombre AS Sexo,
        e.IdTurno,
        t.Nombre AS Turno,
        e.FechaNacimiento,
        e.FechaIngreso,
        e.Rfc,
        e.Curp,
        e.Nss,
        e.Email,
        e.Activo,
        e.FechaRegistro
    FROM rh.Empleado e
    INNER JOIN rh.Puesto       p ON p.IdPuesto       = e.IdPuesto
    INNER JOIN rh.Departamento d ON d.IdDepartamento = e.IdDepartamento
    INNER JOIN cat.Sexo        s ON s.IdSexo         = e.IdSexo
    INNER JOIN cat.Turno       t ON t.IdTurno        = e.IdTurno
    OUTER APPLY (
        SELECT TOP 1 x.IdCartera
        FROM rh.EmpleadoCartera x
        WHERE x.IdEmpleado = e.IdEmpleado AND x.Activo = 1
        ORDER BY x.IdEmpleadoCartera DESC
    ) ec
    LEFT JOIN cart.Cartera c ON c.IdCartera = ec.IdCartera
    OUTER APPLY (
        SELECT TOP 1 su.Usuario
        FROM seg.Usuario su
        WHERE su.IdEmpleado = e.IdEmpleado AND su.Activo = 1
        ORDER BY su.IdUsuario
    ) u
    WHERE (@SoloActivos = 0 OR e.Activo = 1)
      AND (@IdPuesto IS NULL OR e.IdPuesto = @IdPuesto)
      AND (@IdCartera IS NULL OR EXISTS (
            SELECT 1 FROM rh.EmpleadoCartera x
            WHERE x.IdEmpleado = e.IdEmpleado AND x.IdCartera = @IdCartera AND x.Activo = 1))
      AND (@Nombre IS NULL
           OR e.Nombre LIKE '%' + @Nombre + '%'
           OR e.Paterno LIKE '%' + @Nombre + '%'
           OR ISNULL(e.Materno, '') LIKE '%' + @Nombre + '%'
           OR CONCAT(e.Nombre, ' ', e.Paterno, ' ', ISNULL(e.Materno, '')) LIKE '%' + @Nombre + '%')
    ORDER BY e.Paterno, e.Materno, e.Nombre;
END
GO

-- =====================================================================
--  Alta de empleado (paridad con FRM_ALTAEMPLEADOS)
--  El .exe recibia: @ID_BASE, @ID_PUESTO, @ID_SEXO, @ID_TURNO,
--  @NOMBRE, @PATERNO, @MATERNO. Aqui @IdCartera reemplaza a @ID_BASE.
-- =====================================================================
CREATE OR ALTER PROCEDURE rh.USP_ALTA_EMPLEADO
    @IdCartera tinyint,
    @IdPuesto  tinyint,
    @IdSexo    tinyint,
    @IdTurno   tinyint,
    @Nombre    varchar(100),
    @Paterno   varchar(100),
    @Materno   varchar(100) = NULL,
    @Usuario   varchar(50)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Nombre  = NULLIF(LTRIM(RTRIM(@Nombre)), '');
    SET @Paterno = NULLIF(LTRIM(RTRIM(@Paterno)), '');
    SET @Materno = NULLIF(LTRIM(RTRIM(@Materno)), '');

    IF @Nombre IS NULL  THROW 50001, 'Ingresa el nombre del empleado.', 1;
    IF @Paterno IS NULL THROW 50002, 'Ingresa el apellido paterno del empleado.', 1;

    IF NOT EXISTS (SELECT 1 FROM cart.Cartera WHERE IdCartera = @IdCartera AND Activo = 1)
        THROW 50003, 'La cartera seleccionada no existe o esta inactiva.', 1;
    IF NOT EXISTS (SELECT 1 FROM rh.Puesto WHERE IdPuesto = @IdPuesto AND Activo = 1)
        THROW 50004, 'El puesto seleccionado no existe o esta inactivo.', 1;
    IF NOT EXISTS (SELECT 1 FROM cat.Sexo WHERE IdSexo = @IdSexo)
        THROW 50005, 'El sexo seleccionado no existe.', 1;
    IF NOT EXISTS (SELECT 1 FROM cat.Turno WHERE IdTurno = @IdTurno)
        THROW 50006, 'El turno seleccionado no existe.', 1;

    DECLARE @IdDepartamento tinyint =
        ISNULL((SELECT IdDepartamento FROM cart.Cartera WHERE IdCartera = @IdCartera), 12);

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO rh.Empleado
            (Nombre, Paterno, Materno, IdPuesto, IdDepartamento, IdSexo, IdTurno, FechaIngreso, Activo)
        VALUES
            (@Nombre, @Paterno, @Materno, @IdPuesto, @IdDepartamento, @IdSexo, @IdTurno, CONVERT(date, GETDATE()), 1);

        DECLARE @IdEmpleado int = CAST(SCOPE_IDENTITY() AS int);

        INSERT INTO rh.EmpleadoCartera (IdEmpleado, IdCartera, IdDepartamento, Activo)
        VALUES (@IdEmpleado, @IdCartera, @IdDepartamento, 1);

        IF NOT EXISTS (SELECT 1 FROM rh.EmpleadoCarteraAcceso WHERE IdEmpleado = @IdEmpleado AND IdCartera = @IdCartera)
            INSERT INTO rh.EmpleadoCarteraAcceso (IdEmpleado, IdCartera, Activo)
            VALUES (@IdEmpleado, @IdCartera, 1);

        INSERT INTO log.Auditoria (Usuario, Accion, Entidad, IdEntidad, Detalle)
        VALUES (@Usuario, 'ALTA_EMPLEADO', 'rh.Empleado', CAST(@IdEmpleado AS varchar(20)),
                CONCAT('Alta de ', @Nombre, ' ', @Paterno, ' ', ISNULL(@Materno, ''), ' en cartera ', @IdCartera));

        COMMIT TRANSACTION;

        SELECT @IdEmpleado AS IdEmpleado, 'Empleado dado de alta correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- =====================================================================
--  Catalogos para los combos de las pantallas
-- =====================================================================
CREATE OR ALTER PROCEDURE rh.USP_CONSULTA_PUESTOS
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdPuesto, Nombre, Tipo, Gerarquia
    FROM rh.Puesto
    WHERE Activo = 1
    ORDER BY IdPuesto;
END
GO

CREATE OR ALTER PROCEDURE rh.USP_CONSULTA_DEPARTAMENTOS
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdDepartamento, Nombre, Tipo
    FROM rh.Departamento
    WHERE Activo = 1
    ORDER BY IdDepartamento;
END
GO

CREATE OR ALTER PROCEDURE rh.USP_CONSULTA_SEXOS
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdSexo, Nombre FROM cat.Sexo ORDER BY IdSexo;
END
GO

CREATE OR ALTER PROCEDURE rh.USP_CONSULTA_TURNOS
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdTurno, Nombre FROM cat.Turno ORDER BY IdTurno;
END
GO

PRINT 'Modulo RH listo (rh.Empleado, rh.EmpleadoCartera, alta y consulta de empleados).';
GO
