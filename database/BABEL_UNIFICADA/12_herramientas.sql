-- BABEL_UNIFICADA - 12. Tablas y procedimientos de Herramientas/Gestión.
-- Equivalencias del MenuStrip de FRM_GESTION_CARTERA que no existían en 09_gestion.sql.
-- Toda escritura es LOCAL. El servidor legacy 10.80.5.189 solo se lee con SELECT.

SET NOCOUNT ON;
GO

IF OBJECT_ID('ope.Nota', 'U') IS NULL
BEGIN
    CREATE TABLE ope.Nota (
        IdNota bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_Nota PRIMARY KEY,
        IdCuenta bigint NOT NULL CONSTRAINT FK_Nota_Cuenta REFERENCES ope.Cuenta(IdCuenta),
        IdCartera tinyint NOT NULL CONSTRAINT FK_Nota_Cartera REFERENCES cart.Cartera(IdCartera),
        IdEmpleado int NOT NULL,
        TipoSeguimiento varchar(30) NULL,
        FechaSeguimiento datetime2(0) NOT NULL CONSTRAINT DF_Nota_FechaSeg DEFAULT SYSDATETIME(),
        Telefono varchar(30) NULL,
        Pagos int NULL,
        Importe decimal(18,2) NULL,
        Texto nvarchar(4000) NULL,
        FechaRegistro datetime2(0) NOT NULL CONSTRAINT DF_Nota_Registro DEFAULT SYSDATETIME()
    );
    CREATE INDEX IX_Nota_Cuenta ON ope.Nota (IdCartera, IdCuenta, FechaSeguimiento);
END;
GO

IF OBJECT_ID('ope.BlocNota', 'U') IS NULL
BEGIN
    CREATE TABLE ope.BlocNota (
        IdBlocNota bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_BlocNota PRIMARY KEY,
        IdCartera tinyint NOT NULL CONSTRAINT FK_BlocNota_Cartera REFERENCES cart.Cartera(IdCartera),
        IdEmpleado int NOT NULL,
        Texto nvarchar(max) NULL,
        FechaRegistro datetime2(0) NOT NULL CONSTRAINT DF_BlocNota_Registro DEFAULT SYSDATETIME(),
        CONSTRAINT UQ_BlocNota_Empleado UNIQUE (IdCartera, IdEmpleado)
    );
END;
GO

IF OBJECT_ID('ope.Receso', 'U') IS NULL
BEGIN
    CREATE TABLE ope.Receso (
        IdReceso bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_Receso PRIMARY KEY,
        IdCartera tinyint NOT NULL CONSTRAINT FK_Receso_Cartera REFERENCES cart.Cartera(IdCartera),
        IdEmpleado int NOT NULL,
        TipoReceso varchar(50) NULL,
        Inicio datetime2(0) NOT NULL CONSTRAINT DF_Receso_Inicio DEFAULT SYSDATETIME(),
        Fin datetime2(0) NULL,
        Minutos int NULL,
        FechaRegistro datetime2(0) NOT NULL CONSTRAINT DF_Receso_Registro DEFAULT SYSDATETIME()
    );
    CREATE INDEX IX_Receso_Empleado ON ope.Receso (IdCartera, IdEmpleado, Inicio);
END;
GO

IF OBJECT_ID('ope.AgendaLlamada', 'U') IS NULL
BEGIN
    CREATE TABLE ope.AgendaLlamada (
        IdAgenda bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_AgendaLlamada PRIMARY KEY,
        IdCuenta bigint NOT NULL CONSTRAINT FK_Agenda_Cuenta REFERENCES ope.Cuenta(IdCuenta),
        IdCartera tinyint NOT NULL CONSTRAINT FK_Agenda_Cartera REFERENCES cart.Cartera(IdCartera),
        IdEmpleado int NOT NULL,
        FechaHora datetime2(0) NOT NULL,
        Telefono varchar(30) NULL,
        Asunto varchar(200) NULL,
        Estatus varchar(20) NOT NULL CONSTRAINT DF_Agenda_Estatus DEFAULT 'PENDIENTE',
        FechaRegistro datetime2(0) NOT NULL CONSTRAINT DF_Agenda_Registro DEFAULT SYSDATETIME()
    );
    CREATE INDEX IX_Agenda_Cuenta ON ope.AgendaLlamada (IdCartera, IdCuenta, FechaHora);
END;
GO

IF OBJECT_ID('ope.Negociacion', 'U') IS NULL
BEGIN
    CREATE TABLE ope.Negociacion (
        IdNegociacion bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_Negociacion PRIMARY KEY,
        IdCuenta bigint NOT NULL CONSTRAINT FK_Negociacion_Cuenta REFERENCES ope.Cuenta(IdCuenta),
        IdCartera tinyint NOT NULL CONSTRAINT FK_Negociacion_Cartera REFERENCES cart.Cartera(IdCartera),
        IdEmpleado int NOT NULL,
        TipoNegociacion varchar(50) NULL,
        TipoPago varchar(50) NULL,
        MontoOriginal decimal(18,2) NOT NULL,
        PorcentajeDescuento decimal(5,2) NOT NULL DEFAULT 0,
        MontoFinal decimal(18,2) NOT NULL,
        NumeroPagos int NOT NULL DEFAULT 1,
        FechaPrimerPago date NULL,
        Comentario nvarchar(4000) NULL,
        FechaRegistro datetime2(0) NOT NULL CONSTRAINT DF_Negociacion_Registro DEFAULT SYSDATETIME()
    );
    CREATE INDEX IX_Negociacion_Cuenta ON ope.Negociacion (IdCartera, IdCuenta, FechaRegistro);
END;
GO

-- ------------------------------- Notas ------------------------------------
CREATE OR ALTER PROCEDURE ope.USP_CONSULTA_NOTAS
    @IdCartera tinyint,
    @IdCuenta bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT n.IdNota, n.TipoSeguimiento, n.FechaSeguimiento, n.Telefono,
           n.Pagos, n.Importe, n.Texto, n.FechaRegistro,
           e.Nombre AS Empleado
    FROM ope.Nota n
    LEFT JOIN rh.Empleado e ON e.IdEmpleado = n.IdEmpleado
    WHERE n.IdCartera = @IdCartera AND n.IdCuenta = @IdCuenta
    ORDER BY n.FechaSeguimiento DESC, n.IdNota DESC;
END;
GO

CREATE OR ALTER PROCEDURE ope.USP_REGISTRA_NOTA
    @IdCartera tinyint,
    @IdCuenta bigint,
    @IdEmpleado int,
    @TipoSeguimiento varchar(30),
    @FechaSeguimiento datetime2(0),
    @Telefono varchar(30),
    @Pagos int,
    @Importe decimal(18,2),
    @Texto nvarchar(4000),
    @Usuario varchar(50)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM ope.Cuenta WHERE IdCartera=@IdCartera AND IdCuenta=@IdCuenta)
    BEGIN
        SELECT CAST(0 AS bigint) Id, 'La cuenta no pertenece a la cartera activa.' Mensaje;
        RETURN;
    END;

    INSERT INTO ope.Nota (IdCuenta, IdCartera, IdEmpleado, TipoSeguimiento,
                          FechaSeguimiento, Telefono, Pagos, Importe, Texto)
    VALUES (@IdCuenta, @IdCartera, @IdEmpleado, NULLIF(@TipoSeguimiento,''),
            ISNULL(@FechaSeguimiento, SYSDATETIME()), NULLIF(@Telefono,''),
            @Pagos, ISNULL(@Importe,0), NULLIF(@Texto,''));

    SELECT CAST(SCOPE_IDENTITY() AS bigint) Id, 'Nota capturada.' Mensaje;
END;
GO

-- ---------------------------- Bloc de notas -------------------------------
CREATE OR ALTER PROCEDURE ope.USP_CONSULTA_BLOCNOTA
    @IdCartera tinyint,
    @IdEmpleado int
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ISNULL(MAX(Texto), '') Texto, MAX(FechaRegistro) FechaRegistro
    FROM ope.BlocNota
    WHERE IdCartera = @IdCartera AND IdEmpleado = @IdEmpleado;
END;
GO

CREATE OR ALTER PROCEDURE ope.USP_GUARDA_BLOCNOTA
    @IdCartera tinyint,
    @IdEmpleado int,
    @Texto nvarchar(max)
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM ope.BlocNota WHERE IdCartera=@IdCartera AND IdEmpleado=@IdEmpleado)
        UPDATE ope.BlocNota
        SET Texto = @Texto, FechaRegistro = SYSDATETIME()
        WHERE IdCartera = @IdCartera AND IdEmpleado = @IdEmpleado;
    ELSE
        INSERT INTO ope.BlocNota (IdCartera, IdEmpleado, Texto)
        VALUES (@IdCartera, @IdEmpleado, @Texto);

    SELECT CAST(1 AS bigint) Id, 'Bloc de notas guardado.' Mensaje;
END;
GO

-- -------------------------- Recesos / Bloquear ----------------------------
CREATE OR ALTER PROCEDURE ope.USP_INICIA_RECESO
    @IdCartera tinyint,
    @IdEmpleado int,
    @TipoReceso varchar(50)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO ope.Receso (IdCartera, IdEmpleado, TipoReceso)
    VALUES (@IdCartera, @IdEmpleado, NULLIF(@TipoReceso,''));
    SELECT CAST(SCOPE_IDENTITY() AS bigint) Id, Inicio, 'Receso iniciado.' Mensaje
    FROM ope.Receso WHERE IdReceso = SCOPE_IDENTITY();
END;
GO

CREATE OR ALTER PROCEDURE ope.USP_FINALIZA_RECESO
    @IdReceso bigint,
    @IdCartera tinyint,
    @IdEmpleado int
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE ope.Receso
    SET Fin = SYSDATETIME(),
        Minutos = DATEDIFF(MINUTE, Inicio, SYSDATETIME())
    WHERE IdReceso = @IdReceso AND IdCartera = @IdCartera AND IdEmpleado = @IdEmpleado AND Fin IS NULL;

    SELECT IdReceso Id, ISNULL(Minutos,0) Minutos, 'Receso finalizado.' Mensaje
    FROM ope.Receso WHERE IdReceso = @IdReceso;
END;
GO

CREATE OR ALTER PROCEDURE ope.USP_CONSULTA_RECESOS
    @IdCartera tinyint,
    @IdEmpleado int
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (20) IdReceso, TipoReceso, Inicio, Fin, Minutos
    FROM ope.Receso
    WHERE IdCartera = @IdCartera AND IdEmpleado = @IdEmpleado
    ORDER BY Inicio DESC;
END;
GO

-- --------------------------- Agendar llamada ------------------------------
CREATE OR ALTER PROCEDURE ope.USP_CONSULTA_AGENDA
    @IdCartera tinyint,
    @IdCuenta bigint = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT a.IdAgenda, a.IdCuenta, c.NumeroCuenta, c.NombreCliente,
           a.FechaHora, a.Telefono, a.Asunto, a.Estatus,
           e.Nombre AS Empleado
    FROM ope.AgendaLlamada a
    JOIN ope.Cuenta c ON c.IdCuenta = a.IdCuenta
    LEFT JOIN rh.Empleado e ON e.IdEmpleado = a.IdEmpleado
    WHERE a.IdCartera = @IdCartera
      AND (@IdCuenta IS NULL OR a.IdCuenta = @IdCuenta)
    ORDER BY a.FechaHora;
END;
GO

CREATE OR ALTER PROCEDURE ope.USP_REGISTRA_AGENDA
    @IdCartera tinyint,
    @IdCuenta bigint,
    @IdEmpleado int,
    @FechaHora datetime2(0),
    @Telefono varchar(30),
    @Asunto varchar(200)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM ope.Cuenta WHERE IdCartera=@IdCartera AND IdCuenta=@IdCuenta)
    BEGIN
        SELECT CAST(0 AS bigint) Id, 'La cuenta no pertenece a la cartera activa.' Mensaje;
        RETURN;
    END;

    INSERT INTO ope.AgendaLlamada (IdCuenta, IdCartera, IdEmpleado, FechaHora, Telefono, Asunto)
    VALUES (@IdCuenta, @IdCartera, @IdEmpleado, @FechaHora, NULLIF(@Telefono,''), NULLIF(@Asunto,''));

    SELECT CAST(SCOPE_IDENTITY() AS bigint) Id, 'Llamada agendada.' Mensaje;
END;
GO

CREATE OR ALTER PROCEDURE ope.USP_CAMBIA_ESTATUS_AGENDA
    @IdAgenda bigint,
    @IdCartera tinyint,
    @Estatus varchar(20)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE ope.AgendaLlamada
    SET Estatus = @Estatus
    WHERE IdAgenda = @IdAgenda AND IdCartera = @IdCartera;
    SELECT CAST(@IdAgenda AS bigint) Id, 'Estatus actualizado.' Mensaje;
END;
GO

-- --------------------- Negociación / Calculadora --------------------------
CREATE OR ALTER PROCEDURE ope.USP_CONSULTA_NEGOCIACIONES
    @IdCartera tinyint,
    @IdCuenta bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT n.IdNegociacion, n.TipoNegociacion, n.TipoPago, n.MontoOriginal,
           n.PorcentajeDescuento, n.MontoFinal, n.NumeroPagos,
           n.FechaPrimerPago, n.Comentario, n.FechaRegistro,
           e.Nombre AS Empleado
    FROM ope.Negociacion n
    LEFT JOIN rh.Empleado e ON e.IdEmpleado = n.IdEmpleado
    WHERE n.IdCartera = @IdCartera AND n.IdCuenta = @IdCuenta
    ORDER BY n.FechaRegistro DESC;
END;
GO

CREATE OR ALTER PROCEDURE ope.USP_REGISTRA_NEGOCIACION
    @IdCartera tinyint,
    @IdCuenta bigint,
    @IdEmpleado int,
    @TipoNegociacion varchar(50),
    @TipoPago varchar(50),
    @MontoOriginal decimal(18,2),
    @PorcentajeDescuento decimal(5,2),
    @MontoFinal decimal(18,2),
    @NumeroPagos int,
    @FechaPrimerPago date,
    @Comentario nvarchar(4000)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM ope.Cuenta WHERE IdCartera=@IdCartera AND IdCuenta=@IdCuenta)
    BEGIN
        SELECT CAST(0 AS bigint) Id, 'La cuenta no pertenece a la cartera activa.' Mensaje;
        RETURN;
    END;

    INSERT INTO ope.Negociacion (IdCuenta, IdCartera, IdEmpleado, TipoNegociacion,
        TipoPago, MontoOriginal, PorcentajeDescuento, MontoFinal, NumeroPagos,
        FechaPrimerPago, Comentario)
    VALUES (@IdCuenta, @IdCartera, @IdEmpleado, NULLIF(@TipoNegociacion,''),
        NULLIF(@TipoPago,''), @MontoOriginal, @PorcentajeDescuento, @MontoFinal,
        ISNULL(@NumeroPagos,1), @FechaPrimerPago, NULLIF(@Comentario,''));

    SELECT CAST(SCOPE_IDENTITY() AS bigint) Id, 'Negociación guardada.' Mensaje;
END;
GO

-- ----------------------- Actualiza información ----------------------------
CREATE OR ALTER PROCEDURE ope.USP_ACTUALIZA_DEMOGRAFICO
    @IdCartera tinyint,
    @IdCuenta bigint,
    @Calle varchar(200),
    @Colonia varchar(150),
    @CodigoPostal varchar(10),
    @Delegacion varchar(150),
    @Estado varchar(100),
    @Telefono varchar(30),
    @Email varchar(150),
    @Usuario varchar(50)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM ope.Cuenta WHERE IdCartera=@IdCartera AND IdCuenta=@IdCuenta)
    BEGIN
        SELECT CAST(0 AS bigint) Id, 'La cuenta no pertenece a la cartera activa.' Mensaje;
        RETURN;
    END;

    IF EXISTS (SELECT 1 FROM ope.Demografico WHERE IdCartera=@IdCartera AND IdCuenta=@IdCuenta)
    BEGIN
        UPDATE TOP (1) ope.Demografico
        SET Calle = NULLIF(@Calle,''), Colonia = NULLIF(@Colonia,''),
            CodigoPostal = NULLIF(@CodigoPostal,''), Delegacion = NULLIF(@Delegacion,''),
            Estado = NULLIF(@Estado,''), Telefono = NULLIF(@Telefono,''),
            Email = NULLIF(@Email,'')
        WHERE IdCartera = @IdCartera AND IdCuenta = @IdCuenta;

        SELECT TOP (1) IdDemografico Id, 'Información actualizada.' Mensaje
        FROM ope.Demografico WHERE IdCartera=@IdCartera AND IdCuenta=@IdCuenta
        ORDER BY IdDemografico;
    END
    ELSE
    BEGIN
        INSERT INTO ope.Demografico (IdCuenta, IdCartera, Calle, Colonia,
            CodigoPostal, Delegacion, Estado, Telefono, Email)
        VALUES (@IdCuenta, @IdCartera, NULLIF(@Calle,''), NULLIF(@Colonia,''),
            NULLIF(@CodigoPostal,''), NULLIF(@Delegacion,''), NULLIF(@Estado,''),
            NULLIF(@Telefono,''), NULLIF(@Email,''));
        SELECT CAST(SCOPE_IDENTITY() AS bigint) Id, 'Información agregada.' Mensaje;
    END;
END;
GO

PRINT '12_herramientas.sql aplicado correctamente.';
