/*
  BABEL_UNIFICADA - 09. Esquema y procedimientos iniciales de GESTION.

  Equivale a la parte consultable y registrable de FRM_GESTION_CARTERA del
  aplicativo de escritorio. Todas las tablas operativas llevan IdCartera.

  Este script SOLO crea objetos nuevos en la base local BABEL_UNIFICADA.
  No lee ni escribe en 10.80.5.189. La copia de datos legacy se hará después
  de la prueba manual, con otro script y control en mig.ControlCarga.
*/
USE BABEL_UNIFICADA;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET XACT_ABORT ON;
GO

-- ---------- Catálogo de tipos de gestión ----------
IF OBJECT_ID('cat.TipoGestion', 'U') IS NULL
BEGIN
    CREATE TABLE cat.TipoGestion (
        IdTipoGestion tinyint NOT NULL CONSTRAINT PK_TipoGestion PRIMARY KEY,
        Nombre varchar(50) NOT NULL,
        Activo bit NOT NULL CONSTRAINT DF_TipoGestion_Activo DEFAULT 1
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM cat.TipoGestion)
BEGIN
    INSERT INTO cat.TipoGestion (IdTipoGestion, Nombre) VALUES
        (1, 'CONTACTO CON TITULAR'),
        (2, 'PROMESA DE PAGO'),
        (3, 'PAGO REPORTADO'),
        (4, 'RELLAMADA'),
        (5, 'NO CONTESTA'),
        (6, 'SIN ACUERDO'),
        (7, 'GESTION LIBRE');
END;
GO

-- ---------- Cuenta de cartera (equivale a ID CONTROL / NECU_CUENTA) ----------
IF OBJECT_ID('ope.Cuenta', 'U') IS NULL
BEGIN
    CREATE TABLE ope.Cuenta (
        IdCuenta bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_Cuenta PRIMARY KEY,
        IdCartera tinyint NOT NULL CONSTRAINT FK_Cuenta_Cartera
            REFERENCES cart.Cartera(IdCartera),
        IdControlLegacy int NOT NULL,
        NumeroCuenta varchar(50) NOT NULL,
        NombreCliente varchar(200) NULL,
        SituacionCuenta varchar(50) NULL,
        RazonMora varchar(100) NULL,
        Saldo decimal(18,2) NULL,
        IdSegmento tinyint NOT NULL CONSTRAINT DF_Cuenta_Segmento DEFAULT 0,
        IdProducto tinyint NOT NULL CONSTRAINT DF_Cuenta_Producto DEFAULT 0,
        IdCampana tinyint NOT NULL CONSTRAINT DF_Cuenta_Campana DEFAULT 0,
        IdEmpleado int NULL CONSTRAINT FK_Cuenta_Empleado REFERENCES rh.Empleado(IdEmpleado),
        Activo bit NOT NULL CONSTRAINT DF_Cuenta_Activo DEFAULT 1,
        FechaRegistro datetime2(0) NOT NULL CONSTRAINT DF_Cuenta_Fecha DEFAULT SYSDATETIME(),
        CONSTRAINT UQ_Cuenta_Legacy UNIQUE (IdCartera, IdControlLegacy)
    );
    CREATE INDEX IX_Cuenta_Cartera_Numero ON ope.Cuenta (IdCartera, NumeroCuenta);
END;
GO

-- ---------- Teléfonos (NEBT_BASE_TELEFONICA / NEDT_DATOS_TELEFONO) ----------
IF OBJECT_ID('ope.Telefono', 'U') IS NULL
BEGIN
    CREATE TABLE ope.Telefono (
        IdTelefono bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_Telefono PRIMARY KEY,
        IdCuenta bigint NOT NULL CONSTRAINT FK_Telefono_Cuenta REFERENCES ope.Cuenta(IdCuenta),
        IdCartera tinyint NOT NULL CONSTRAINT FK_Telefono_Cartera REFERENCES cart.Cartera(IdCartera),
        Numero varchar(30) NOT NULL,
        Tipo varchar(20) NULL,
        Calificacion tinyint NULL,
        Origen varchar(50) NULL,
        IdRegistroLegacy int NULL,
        Activo bit NOT NULL CONSTRAINT DF_Telefono_Activo DEFAULT 1,
        FechaRegistro datetime2(0) NOT NULL CONSTRAINT DF_Telefono_Fecha DEFAULT SYSDATETIME()
    );
    CREATE INDEX IX_Telefono_Cuenta ON ope.Telefono (IdCartera, IdCuenta, Activo);
END;
GO

-- ---------- Gestiones (NEGE_GESTION) ----------
IF OBJECT_ID('ope.Gestion', 'U') IS NULL
BEGIN
    CREATE TABLE ope.Gestion (
        IdGestion bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_Gestion PRIMARY KEY,
        IdCuenta bigint NOT NULL CONSTRAINT FK_Gestion_Cuenta REFERENCES ope.Cuenta(IdCuenta),
        IdCartera tinyint NOT NULL CONSTRAINT FK_Gestion_Cartera REFERENCES cart.Cartera(IdCartera),
        IdEmpleado int NOT NULL CONSTRAINT FK_Gestion_Empleado REFERENCES rh.Empleado(IdEmpleado),
        IdTipoGestion tinyint NOT NULL CONSTRAINT FK_Gestion_Tipo REFERENCES cat.TipoGestion(IdTipoGestion),
        IdTelefono bigint NULL CONSTRAINT FK_Gestion_Telefono REFERENCES ope.Telefono(IdTelefono),
        TelefonoMarcado varchar(30) NULL,
        Comentario nvarchar(max) NULL,
        Inbound bit NOT NULL CONSTRAINT DF_Gestion_Inbound DEFAULT 0,
        FechaInicio datetime2(0) NOT NULL CONSTRAINT DF_Gestion_Inicio DEFAULT SYSDATETIME(),
        FechaFin datetime2(0) NULL,
        TiempoLlamadaSegundos int NULL,
        TiempoEscrituraSegundos int NULL,
        IdIntegracionLegacy int NULL,
        IdRegistroLegacy int NULL,
        FechaRegistro datetime2(0) NOT NULL CONSTRAINT DF_Gestion_Fecha DEFAULT SYSDATETIME()
    );
    CREATE INDEX IX_Gestion_Cuenta ON ope.Gestion (IdCartera, IdCuenta, FechaInicio DESC);
END;
GO

-- ---------- Promesas de pago (NEPR_PROMESAS) ----------
IF OBJECT_ID('ope.Promesa', 'U') IS NULL
BEGIN
    CREATE TABLE ope.Promesa (
        IdPromesa bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_Promesa PRIMARY KEY,
        IdCuenta bigint NOT NULL CONSTRAINT FK_Promesa_Cuenta REFERENCES ope.Cuenta(IdCuenta),
        IdCartera tinyint NOT NULL CONSTRAINT FK_Promesa_Cartera REFERENCES cart.Cartera(IdCartera),
        IdGestion bigint NULL CONSTRAINT FK_Promesa_Gestion REFERENCES ope.Gestion(IdGestion),
        Monto decimal(18,2) NOT NULL,
        FechaPromesa date NOT NULL,
        LugarPago varchar(100) NULL,
        FuenteIngreso varchar(100) NULL,
        RazonMora varchar(100) NULL,
        Notas nvarchar(max) NULL,
        Estatus varchar(20) NOT NULL CONSTRAINT DF_Promesa_Estatus DEFAULT 'PENDIENTE',
        IdRegistroLegacy int NULL,
        FechaRegistro datetime2(0) NOT NULL CONSTRAINT DF_Promesa_Fecha DEFAULT SYSDATETIME()
    );
    CREATE INDEX IX_Promesa_Cuenta ON ope.Promesa (IdCartera, IdCuenta, FechaPromesa);
END;
GO

-- ---------- Demográficos (NEDE_DEMOGRAFICOS) ----------
IF OBJECT_ID('ope.Demografico', 'U') IS NULL
BEGIN
    CREATE TABLE ope.Demografico (
        IdDemografico bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_Demografico PRIMARY KEY,
        IdCuenta bigint NOT NULL CONSTRAINT FK_Demografico_Cuenta REFERENCES ope.Cuenta(IdCuenta),
        IdCartera tinyint NOT NULL CONSTRAINT FK_Demografico_Cartera REFERENCES cart.Cartera(IdCartera),
        Calle varchar(200) NULL,
        Colonia varchar(150) NULL,
        CodigoPostal varchar(10) NULL,
        Delegacion varchar(150) NULL,
        Estado varchar(100) NULL,
        Telefono varchar(30) NULL,
        Email varchar(150) NULL,
        IdRegistroLegacy int NULL,
        FechaRegistro datetime2(0) NOT NULL CONSTRAINT DF_Demografico_Fecha DEFAULT SYSDATETIME()
    );
    CREATE INDEX IX_Demografico_Cuenta ON ope.Demografico (IdCartera, IdCuenta);
END;
GO

-- ---------- Mora / fuente de ingreso (NEMF_MORA_FUENTE_INGRESO) ----------
IF OBJECT_ID('ope.MoraFuenteIngreso', 'U') IS NULL
BEGIN
    CREATE TABLE ope.MoraFuenteIngreso (
        IdMoraFuente bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_MoraFuente PRIMARY KEY,
        IdCuenta bigint NOT NULL CONSTRAINT FK_MoraFuente_Cuenta REFERENCES ope.Cuenta(IdCuenta),
        IdCartera tinyint NOT NULL CONSTRAINT FK_MoraFuente_Cartera REFERENCES cart.Cartera(IdCartera),
        IdGestion bigint NULL CONSTRAINT FK_MoraFuente_Gestion REFERENCES ope.Gestion(IdGestion),
        FuenteIngreso varchar(100) NULL,
        RazonMora varchar(100) NULL,
        Intencion varchar(100) NULL,
        Comentario nvarchar(max) NULL,
        IdRegistroLegacy int NULL,
        FechaRegistro datetime2(0) NOT NULL CONSTRAINT DF_MoraFuente_Fecha DEFAULT SYSDATETIME()
    );
    CREATE INDEX IX_MoraFuente_Cuenta ON ope.MoraFuenteIngreso (IdCartera, IdCuenta);
END;
GO

-- ---------- Evolución de cuenta (HIEC_EVOLUCION_CUENTA) ----------
IF OBJECT_ID('ope.EvolucionCuenta', 'U') IS NULL
BEGIN
    CREATE TABLE ope.EvolucionCuenta (
        IdEvolucion bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_Evolucion PRIMARY KEY,
        IdCuenta bigint NOT NULL CONSTRAINT FK_Evolucion_Cuenta REFERENCES ope.Cuenta(IdCuenta),
        IdCartera tinyint NOT NULL CONSTRAINT FK_Evolucion_Cartera REFERENCES cart.Cartera(IdCartera),
        FechaEvento datetime2(0) NULL,
        Campo varchar(100) NULL,
        ValorAnterior varchar(300) NULL,
        ValorNuevo varchar(300) NULL,
        IdRegistroLegacy int NULL,
        FechaRegistro datetime2(0) NOT NULL CONSTRAINT DF_Evolucion_Fecha DEFAULT SYSDATETIME()
    );
    CREATE INDEX IX_Evolucion_Cuenta ON ope.EvolucionCuenta (IdCartera, IdCuenta, FechaEvento);
END;
GO

-- ---------- Campos adicionales sin traducir (NECU_DATOSCUENTA y afines) ----------
-- Tabla de preservación:evita perder información cuyo significado exacto se
-- confirmará con sistemas durante la fase de migración.
IF OBJECT_ID('ope.DatoCuenta', 'U') IS NULL
BEGIN
    CREATE TABLE ope.DatoCuenta (
        IdDato bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_DatoCuenta PRIMARY KEY,
        IdCuenta bigint NOT NULL CONSTRAINT FK_DatoCuenta_Cuenta REFERENCES ope.Cuenta(IdCuenta),
        IdCartera tinyint NOT NULL CONSTRAINT FK_DatoCuenta_Cartera REFERENCES cart.Cartera(IdCartera),
        NombreCampo varchar(100) NOT NULL,
        Valor nvarchar(max) NULL,
        IdRegistroLegacy int NULL,
        FechaRegistro datetime2(0) NOT NULL CONSTRAINT DF_DatoCuenta_Fecha DEFAULT SYSDATETIME()
    );
    CREATE INDEX IX_DatoCuenta_Cuenta ON ope.DatoCuenta (IdCartera, IdCuenta, NombreCampo);
END;
GO

-- ==========================================================================
-- Procedimientos
-- ==========================================================================

CREATE OR ALTER PROCEDURE ope.USP_CONSULTA_TIPOS_GESTION
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdTipoGestion, Nombre
    FROM cat.TipoGestion
    WHERE Activo = 1
    ORDER BY IdTipoGestion;
END;
GO

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
      AND (@Filtro IS NULL
           OR c.NumeroCuenta LIKE '%' + @Filtro + '%'
           OR c.NombreCliente LIKE '%' + @Filtro + '%'
           OR CONVERT(varchar(20), c.IdControlLegacy) = @Filtro)
    ORDER BY c.FechaRegistro DESC, c.IdCuenta DESC;
END;
GO

CREATE OR ALTER PROCEDURE ope.USP_CREA_CUENTA
    @IdCartera tinyint,
    @IdControlLegacy int,
    @NumeroCuenta varchar(50),
    @NombreCliente varchar(200) = NULL,
    @SituacionCuenta varchar(50) = NULL,
    @RazonMora varchar(100) = NULL,
    @Saldo decimal(18,2) = NULL,
    @IdEmpleado int = NULL,
    @Usuario varchar(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM cart.Cartera WHERE IdCartera = @IdCartera AND Activo = 1)
            THROW 50061, 'La cartera de la sesión no está activa.', 1;
        IF @IdControlLegacy IS NULL OR @IdControlLegacy <= 0
            THROW 50062, 'El ID de control es obligatorio.', 1;

        DECLARE @Numero varchar(50) = NULLIF(LTRIM(RTRIM(@NumeroCuenta)), '');
        IF @Numero IS NULL
            THROW 50063, 'El número de cuenta es obligatorio.', 1;
        IF EXISTS (SELECT 1 FROM ope.Cuenta WHERE IdCartera = @IdCartera AND IdControlLegacy = @IdControlLegacy)
            THROW 50064, 'Ya existe una cuenta con ese ID de control en la cartera.', 1;

        INSERT INTO ope.Cuenta
            (IdCartera, IdControlLegacy, NumeroCuenta, NombreCliente, SituacionCuenta,
             RazonMora, Saldo, IdEmpleado, FechaRegistro)
        VALUES
            (@IdCartera, @IdControlLegacy, @Numero,
             NULLIF(LTRIM(RTRIM(@NombreCliente)), ''),
             NULLIF(LTRIM(RTRIM(@SituacionCuenta)), ''),
             NULLIF(LTRIM(RTRIM(@RazonMora)), ''),
             @Saldo, @IdEmpleado, SYSDATETIME());

        DECLARE @Id bigint = SCOPE_IDENTITY();

        INSERT INTO log.Auditoria (Usuario, Accion, Entidad, IdEntidad, Detalle, Fecha)
        VALUES (ISNULL(@Usuario, 'SISTEMA'), 'ALTA', 'ope.Cuenta', CONVERT(varchar(20), @Id),
                CONCAT('Cartera ', @IdCartera, '; control ', @IdControlLegacy, '; cuenta ', @Numero), SYSDATETIME());

        COMMIT TRANSACTION;

        SELECT @Id AS IdCuenta, 'Cuenta capturada.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE ope.USP_CONSULTA_CUENTA
    @IdCartera tinyint,
    @IdCuenta bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1)
        c.IdCuenta, c.IdCartera, ca.Nombre AS Cartera, c.IdControlLegacy,
        c.NumeroCuenta, c.NombreCliente, c.SituacionCuenta, c.RazonMora, c.Saldo,
        c.IdSegmento, c.IdProducto, c.IdCampana, c.Activo, c.FechaRegistro
    FROM ope.Cuenta c
    JOIN cart.Cartera ca ON ca.IdCartera = c.IdCartera
    WHERE c.IdCartera = @IdCartera AND c.IdCuenta = @IdCuenta;
END;
GO

CREATE OR ALTER PROCEDURE ope.USP_CONSULTA_TELEFONOS
    @IdCartera tinyint,
    @IdCuenta bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdTelefono, Numero, Tipo, Calificacion, Origen, Activo, FechaRegistro
    FROM ope.Telefono
    WHERE IdCartera = @IdCartera AND IdCuenta = @IdCuenta
    ORDER BY IdTelefono;
END;
GO

CREATE OR ALTER PROCEDURE ope.USP_REGISTRA_TELEFONO
    @IdCartera tinyint,
    @IdCuenta bigint,
    @Numero varchar(30),
    @Tipo varchar(20) = NULL,
    @Calificacion tinyint = NULL,
    @Origen varchar(50) = NULL,
    @Usuario varchar(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM ope.Cuenta WHERE IdCartera = @IdCartera AND IdCuenta = @IdCuenta AND Activo = 1)
        THROW 50065, 'La cuenta no pertenece a la cartera activa.', 1;

    DECLARE @Tel varchar(30) = NULLIF(LTRIM(RTRIM(@Numero)), '');
    IF @Tel IS NULL THROW 50066, 'El teléfono es obligatorio.', 1;

    INSERT INTO ope.Telefono (IdCuenta, IdCartera, Numero, Tipo, Calificacion, Origen, FechaRegistro)
    VALUES (@IdCuenta, @IdCartera, @Tel, NULLIF(LTRIM(RTRIM(@Tipo)), ''), @Calificacion,
            NULLIF(LTRIM(RTRIM(@Origen)), ''), SYSDATETIME());

    SELECT SCOPE_IDENTITY() AS IdTelefono, 'Teléfono capturado.' AS Mensaje;
END;
GO

CREATE OR ALTER PROCEDURE ope.USP_CONSULTA_GESTIONES
    @IdCartera tinyint,
    @IdCuenta bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (200)
        g.IdGestion, g.IdTipoGestion, tg.Nombre AS TipoGestion, g.Comentario,
        g.TelefonoMarcado, g.Inbound, g.FechaInicio, g.FechaFin,
        g.TiempoLlamadaSegundos, g.TiempoEscrituraSegundos,
        CONCAT_WS(' ', e.Nombre, e.Paterno, e.Materno) AS Empleado
    FROM ope.Gestion g
    JOIN cat.TipoGestion tg ON tg.IdTipoGestion = g.IdTipoGestion
    JOIN rh.Empleado e ON e.IdEmpleado = g.IdEmpleado
    WHERE g.IdCartera = @IdCartera AND g.IdCuenta = @IdCuenta
    ORDER BY g.FechaInicio DESC, g.IdGestion DESC;
END;
GO

CREATE OR ALTER PROCEDURE ope.USP_REGISTRA_GESTION
    @IdCartera tinyint,
    @IdCuenta bigint,
    @IdEmpleado int,
    @IdTipoGestion tinyint,
    @Comentario nvarchar(max) = NULL,
    @IdTelefono bigint = NULL,
    @TelefonoMarcado varchar(30) = NULL,
    @Inbound bit = 0,
    @TiempoLlamadaSegundos int = NULL,
    @TiempoEscrituraSegundos int = NULL,
    @Usuario varchar(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM ope.Cuenta WHERE IdCartera = @IdCartera AND IdCuenta = @IdCuenta AND Activo = 1)
            THROW 50067, 'La cuenta no pertenece a la cartera activa.', 1;
        IF NOT EXISTS (SELECT 1 FROM cat.TipoGestion WHERE IdTipoGestion = @IdTipoGestion AND Activo = 1)
            THROW 50068, 'El tipo de gestión no es válido.', 1;
        IF @IdEmpleado IS NULL OR @IdEmpleado <= 0
            THROW 50069, 'La sesión no tiene un empleado válido.', 1;

        IF @IdTelefono IS NOT NULL AND NOT EXISTS
            (SELECT 1 FROM ope.Telefono WHERE IdTelefono = @IdTelefono AND IdCartera = @IdCartera AND IdCuenta = @IdCuenta)
            THROW 50070, 'El teléfono no pertenece a la cuenta.', 1;

        INSERT INTO ope.Gestion
            (IdCuenta, IdCartera, IdEmpleado, IdTipoGestion, IdTelefono, TelefonoMarcado,
             Comentario, Inbound, FechaInicio, FechaFin,
             TiempoLlamadaSegundos, TiempoEscrituraSegundos, FechaRegistro)
        VALUES
            (@IdCuenta, @IdCartera, @IdEmpleado, @IdTipoGestion, @IdTelefono,
             NULLIF(LTRIM(RTRIM(@TelefonoMarcado)), ''), NULLIF(LTRIM(RTRIM(@Comentario)), ''),
             @Inbound, SYSDATETIME(), SYSDATETIME(),
             @TiempoLlamadaSegundos, @TiempoEscrituraSegundos, SYSDATETIME());

        DECLARE @Id bigint = SCOPE_IDENTITY();

        UPDATE ope.Cuenta SET IdEmpleado = @IdEmpleado
        WHERE IdCartera = @IdCartera AND IdCuenta = @IdCuenta AND IdEmpleado IS NULL;

        INSERT INTO log.Auditoria (Usuario, Accion, Entidad, IdEntidad, Detalle, Fecha)
        VALUES (ISNULL(@Usuario, 'SISTEMA'), 'ALTA', 'ope.Gestion', CONVERT(varchar(20), @Id),
                CONCAT('Cartera ', @IdCartera, '; cuenta ', @IdCuenta, '; tipo ', @IdTipoGestion), SYSDATETIME());

        COMMIT TRANSACTION;

        SELECT @Id AS IdGestion, 'Gestión registrada.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE ope.USP_CONSULTA_PROMESAS
    @IdCartera tinyint,
    @IdCuenta bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdPromesa, Monto, FechaPromesa, LugarPago, FuenteIngreso,
           RazonMora, Notas, Estatus, IdGestion, FechaRegistro
    FROM ope.Promesa
    WHERE IdCartera = @IdCartera AND IdCuenta = @IdCuenta
    ORDER BY FechaPromesa DESC, IdPromesa DESC;
END;
GO

CREATE OR ALTER PROCEDURE ope.USP_REGISTRA_PROMESA
    @IdCartera tinyint,
    @IdCuenta bigint,
    @IdGestion bigint = NULL,
    @Monto decimal(18,2),
    @FechaPromesa date,
    @LugarPago varchar(100) = NULL,
    @FuenteIngreso varchar(100) = NULL,
    @RazonMora varchar(100) = NULL,
    @Notas nvarchar(max) = NULL,
    @Usuario varchar(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM ope.Cuenta WHERE IdCartera = @IdCartera AND IdCuenta = @IdCuenta AND Activo = 1)
            THROW 50071, 'La cuenta no pertenece a la cartera activa.', 1;
        IF @Monto IS NULL OR @Monto <= 0
            THROW 50072, 'El monto de la promesa debe ser mayor a cero.', 1;
        IF @FechaPromesa IS NULL OR @FechaPromesa < CONVERT(date, GETDATE())
            THROW 50073, 'La fecha de promesa no puede ser anterior a hoy.', 1;
        IF @IdGestion IS NOT NULL AND NOT EXISTS
            (SELECT 1 FROM ope.Gestion WHERE IdGestion = @IdGestion AND IdCartera = @IdCartera AND IdCuenta = @IdCuenta)
            THROW 50074, 'La gestión no pertenece a la cuenta.', 1;

        INSERT INTO ope.Promesa
            (IdCuenta, IdCartera, IdGestion, Monto, FechaPromesa, LugarPago,
             FuenteIngreso, RazonMora, Notas, Estatus, FechaRegistro)
        VALUES
            (@IdCuenta, @IdCartera, @IdGestion, @Monto, @FechaPromesa,
             NULLIF(LTRIM(RTRIM(@LugarPago)), ''),
             NULLIF(LTRIM(RTRIM(@FuenteIngreso)), ''),
             NULLIF(LTRIM(RTRIM(@RazonMora)), ''),
             NULLIF(LTRIM(RTRIM(@Notas)), ''), 'PENDIENTE', SYSDATETIME());

        DECLARE @Id bigint = SCOPE_IDENTITY();

        INSERT INTO log.Auditoria (Usuario, Accion, Entidad, IdEntidad, Detalle, Fecha)
        VALUES (ISNULL(@Usuario, 'SISTEMA'), 'ALTA', 'ope.Promesa', CONVERT(varchar(20), @Id),
                CONCAT('Cartera ', @IdCartera, '; cuenta ', @IdCuenta, '; monto ', @Monto), SYSDATETIME());

        COMMIT TRANSACTION;

        SELECT @Id AS IdPromesa, 'Promesa registrada.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE ope.USP_CONSULTA_DEMOGRAFICOS
    @IdCartera tinyint,
    @IdCuenta bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (50) IdDemografico, Calle, Colonia, CodigoPostal, Delegacion,
           Estado, Telefono, Email, FechaRegistro
    FROM ope.Demografico
    WHERE IdCartera = @IdCartera AND IdCuenta = @IdCuenta
    ORDER BY IdDemografico DESC;
END;
GO

PRINT 'Esquema y procedimientos de Gestión listos.';
GO
