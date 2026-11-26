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

-- Registro repetido de la misma persona (BABEL la da de alta otra vez por cartera/reingreso):
-- queda inactivo y apunta al empleado que la representa. La migración debe mapear su
-- IdEmpleadoLegacy a ISNULL(IdEmpleadoUnificado, IdEmpleado). Ver 20_rh_unificar_empleados.sql.
IF COL_LENGTH('rh.Empleado', 'IdEmpleadoUnificado') IS NULL
    ALTER TABLE rh.Empleado ADD IdEmpleadoUnificado int NULL
        CONSTRAINT FK_Empleado_Unificado REFERENCES rh.Empleado (IdEmpleado);
GO

-- Horario (26/11/2026): el alta ya no captura turno (matutino/vespertino) sino hora de
-- entrada y salida. Los empleados migrados de BABEL conservan su IdTurno (no hay horas allá).
IF COL_LENGTH('rh.Empleado', 'HoraEntrada') IS NULL
    ALTER TABLE rh.Empleado ADD HoraEntrada time(0) NULL, HoraSalida time(0) NULL;
GO
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('rh.Empleado') AND name = 'IdTurno' AND is_nullable = 0)
    ALTER TABLE rh.Empleado ALTER COLUMN IdTurno tinyint NULL;
GO
-- AplicaHorario = 0: el empleado puede entrar a cualquier hora (lo decide el admin, o se
-- guardó sin hora de entrada ni de salida). Con 1, el login solo lo deja entrar dentro de
-- su horario (10 min de tolerancia antes de la entrada; ver PoliticaHorario en el backend).
IF COL_LENGTH('rh.Empleado', 'AplicaHorario') IS NULL
    ALTER TABLE rh.Empleado ADD AplicaHorario bit NOT NULL CONSTRAINT DF_Empleado_AplicaHorario DEFAULT (1);
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
        e.HoraEntrada,
        e.HoraSalida,
        e.AplicaHorario,
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
    LEFT JOIN  cat.Turno       t ON t.IdTurno        = e.IdTurno   -- altas nuevas: horario en vez de turno
    OUTER APPLY (
        -- Cartera activa; si está dado de baja (su asignación se cerró), la ÚLTIMA en la que estuvo.
        SELECT TOP 1 x.IdCartera
        FROM rh.EmpleadoCartera x
        WHERE x.IdEmpleado = e.IdEmpleado
        ORDER BY x.Activo DESC, x.IdEmpleadoCartera DESC
    ) ec
    LEFT JOIN cart.Cartera c ON c.IdCartera = ec.IdCartera
    OUTER APPLY (
        SELECT TOP 1 su.Usuario
        FROM seg.Usuario su
        WHERE su.IdEmpleado = e.IdEmpleado   -- también si está inactivo (dado de baja)
        ORDER BY su.Activo DESC, su.IdUsuario
    ) u
    WHERE (@SoloActivos = 0 OR e.Activo = 1)
      AND e.IdEmpleadoUnificado IS NULL   -- los registros repetidos ya unificados no se listan
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
--  Reglas del horario (alta y edición):
--   - Sin hora de entrada ni de salida => no aplica horario (@AplicaHorario = 0).
--   - Solo una de las dos => error.
--   - Con las dos: jornada de 1 a 12 horas; puede cruzar la medianoche (22:00-06:00).
--   - Con "no aplica horario" las horas son opcionales (solo informativas).
-- =====================================================================
CREATE OR ALTER PROCEDURE rh.USP_VALIDA_HORARIO
    @HoraEntrada   time(0) OUTPUT,
    @HoraSalida    time(0) OUTPUT,
    @AplicaHorario bit     OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @AplicaHorario = ISNULL(@AplicaHorario, 1);

    IF @HoraEntrada IS NULL AND @HoraSalida IS NULL
    BEGIN
        SET @AplicaHorario = 0;
        RETURN;
    END
    IF @HoraEntrada IS NULL OR @HoraSalida IS NULL
        THROW 50006, 'Captura la hora de entrada y la hora de salida, o deja las dos vacías si no aplica horario.', 1;

    DECLARE @MinutosJornada int = DATEDIFF(MINUTE, @HoraEntrada, @HoraSalida);
    IF @MinutosJornada < 0 SET @MinutosJornada += 1440;
    IF @MinutosJornada < 60 OR @MinutosJornada > 720
        THROW 50008, 'La jornada debe durar entre 1 y 12 horas. Revisa la hora de entrada y de salida.', 1;
END
GO

-- =====================================================================
--  Alta de empleado (paridad con FRM_ALTAEMPLEADOS)
--  El .exe recibia: @ID_BASE, @ID_PUESTO, @ID_SEXO, @ID_TURNO,
--  @NOMBRE, @PATERNO, @MATERNO. Aqui @IdCartera reemplaza a @ID_BASE y
--  el turno se reemplaza por hora de entrada y salida (26/11/2026).
-- =====================================================================
CREATE OR ALTER PROCEDURE rh.USP_ALTA_EMPLEADO
    @IdCartera   tinyint,
    @IdPuesto    tinyint,
    @IdSexo      tinyint,
    @HoraEntrada time(0) = NULL,
    @HoraSalida  time(0) = NULL,
    @AplicaHorario bit   = 1,   -- 0 = "No aplica horario" (entra a cualquier hora)
    @Nombre    varchar(100),
    @Paterno   varchar(100),
    @Materno   varchar(100) = NULL,
    @Usuario   varchar(50)  = NULL,
    @ConfirmarHomonimo bit  = 0,    -- 1 = el admin confirmó que es OTRA persona con el mismo nombre
    -- Usuario del sistema (26/11/2026): el alta lo crea en la MISMA transacción.
    -- @UsuarioBase = inicial + apellido ya normalizado por el backend (sin acentos ni espacios);
    -- aquí solo se agrega 2, 3… si ya existe. @HashContrasena = hash PBKDF2 de la contraseña temporal.
    @UsuarioBase    varchar(45)  = NULL,
    @HashContrasena varchar(200) = NULL,
    -- Ajustes de permisos contra lo de su puesto: 'clave:1,clave:0' (NULL = solo lo del puesto).
    @Permisos       varchar(max) = NULL,
    -- Multi-campaña (26/11/2026): @IdCartera = campaña PRINCIPAL; aquí las demás ('3,7,12'),
    -- que quedan como acceso (rh.EmpleadoCarteraAcceso) para "Cambia cartera".
    @CarterasAcceso varchar(max) = NULL
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
    -- Horario: sin hora de entrada ni salida = no aplica horario.
    EXEC rh.USP_VALIDA_HORARIO @HoraEntrada = @HoraEntrada OUTPUT, @HoraSalida = @HoraSalida OUTPUT,
                               @AplicaHorario = @AplicaHorario OUTPUT;

    -- No dar de alta otra vez a la misma persona (BABEL lo hacía por cartera/reingreso).
    -- Ver 19_rh_alta_sin_duplicados.sql: la pantalla ofrece moverlo, darle acceso o reactivarlo.
    IF @ConfirmarHomonimo = 0 AND EXISTS (
        SELECT 1 FROM rh.Empleado e
        WHERE e.IdEmpleadoUnificado IS NULL
          AND LTRIM(RTRIM(e.Nombre))               COLLATE Latin1_General_CI_AI = @Nombre  COLLATE Latin1_General_CI_AI
          AND LTRIM(RTRIM(e.Paterno))              COLLATE Latin1_General_CI_AI = @Paterno COLLATE Latin1_General_CI_AI
          AND LTRIM(RTRIM(ISNULL(e.Materno, ''))) COLLATE Latin1_General_CI_AI = ISNULL(@Materno, '') COLLATE Latin1_General_CI_AI)
        THROW 50007, 'Ya existe un empleado con ese nombre. Revisa las coincidencias antes de darlo de alta.', 1;

    DECLARE @IdDepartamento tinyint =
        ISNULL((SELECT IdDepartamento FROM cart.Cartera WHERE IdCartera = @IdCartera), 12);

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO rh.Empleado
            (Nombre, Paterno, Materno, IdPuesto, IdDepartamento, IdSexo, IdTurno, HoraEntrada, HoraSalida, AplicaHorario, FechaIngreso, Activo)
        VALUES
            (@Nombre, @Paterno, @Materno, @IdPuesto, @IdDepartamento, @IdSexo, NULL, @HoraEntrada, @HoraSalida, @AplicaHorario, CONVERT(date, GETDATE()), 1);

        DECLARE @IdEmpleado int = CAST(SCOPE_IDENTITY() AS int);

        INSERT INTO rh.EmpleadoCartera (IdEmpleado, IdCartera, IdDepartamento, Activo)
        VALUES (@IdEmpleado, @IdCartera, @IdDepartamento, 1);

        IF NOT EXISTS (SELECT 1 FROM rh.EmpleadoCarteraAcceso WHERE IdEmpleado = @IdEmpleado AND IdCartera = @IdCartera)
            INSERT INTO rh.EmpleadoCarteraAcceso (IdEmpleado, IdCartera, Activo)
            VALUES (@IdEmpleado, @IdCartera, 1);

        -- Las demás campañas elegidas (solo activas; sin repetir).
        INSERT INTO rh.EmpleadoCarteraAcceso (IdEmpleado, IdCartera, Activo)
        SELECT DISTINCT @IdEmpleado, c.IdCartera, 1
        FROM STRING_SPLIT(ISNULL(@CarterasAcceso, ''), ',') s
        JOIN cart.Cartera c ON c.IdCartera = TRY_CAST(s.value AS tinyint) AND c.Activo = 1
        WHERE c.IdCartera <> @IdCartera
          AND NOT EXISTS (SELECT 1 FROM rh.EmpleadoCarteraAcceso a WHERE a.IdEmpleado = @IdEmpleado AND a.IdCartera = c.IdCartera);

        -- Usuario del sistema con cambio de contraseña obligatorio al primer acceso.
        DECLARE @UsuarioNuevo varchar(50) = NULL;
        IF @UsuarioBase IS NOT NULL AND @HashContrasena IS NOT NULL
        BEGIN
            SET @UsuarioNuevo = @UsuarioBase;
            DECLARE @Sufijo int = 2;
            -- UPDLOCK/HOLDLOCK: dos altas simultáneas no pueden tomar el mismo usuario.
            WHILE EXISTS (SELECT 1 FROM seg.Usuario WITH (UPDLOCK, HOLDLOCK) WHERE Usuario = @UsuarioNuevo)
            BEGIN
                SET @UsuarioNuevo = CONCAT(@UsuarioBase, @Sufijo);
                SET @Sufijo += 1;
            END

            INSERT INTO seg.Usuario
                (Usuario, HashContrasena, IdEmpleado, IdPuesto, IdDepartamento, Activo, Bloqueado,
                 DebeCambiarContrasena, FechaCambioContrasena)
            VALUES
                (@UsuarioNuevo, @HashContrasena, @IdEmpleado, @IdPuesto, @IdDepartamento, 1, 0, 1, SYSDATETIME());

            IF NULLIF(@Permisos, '') IS NOT NULL
            BEGIN
                DECLARE @IdUsuarioNuevo int = CAST(SCOPE_IDENTITY() AS int);
                EXEC seg.USP_GUARDA_PERMISOS @IdUsuario = @IdUsuarioNuevo, @Permisos = @Permisos, @Usuario = @Usuario;
            END
        END

        INSERT INTO log.Auditoria (Usuario, Accion, Entidad, IdEntidad, Detalle)
        VALUES (@Usuario, 'ALTA_EMPLEADO', 'rh.Empleado', CAST(@IdEmpleado AS varchar(20)),
                CONCAT('Alta de ', @Nombre, ' ', @Paterno, ' ', ISNULL(@Materno, ''), ' en cartera ', @IdCartera,
                       CASE WHEN @UsuarioNuevo IS NULL THEN '' ELSE CONCAT('; usuario ', @UsuarioNuevo) END));

        COMMIT TRANSACTION;

        SELECT @IdEmpleado AS IdEmpleado, 'Empleado dado de alta correctamente.' AS Mensaje, @UsuarioNuevo AS Usuario;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- =====================================================================
--  Edición de empleado (NUEVO: BABEL nunca tuvo pantalla para editar).
--  Nombre, puesto, sexo y horario. Solo empleados activos de la cartera
--  de la sesión. Si cambia el puesto, también cambia en su usuario (el
--  perfil de acceso sale de seg.Usuario.IdPuesto). Queda en log.Auditoria
--  quién cambió qué y cuándo.
-- =====================================================================
CREATE OR ALTER PROCEDURE rh.USP_EDITA_EMPLEADO
    @IdEmpleado    int,
    @IdCartera     tinyint,
    @Nombre        varchar(100),
    @Paterno       varchar(100),
    @Materno       varchar(100),
    @IdPuesto      tinyint,
    @IdSexo        tinyint,
    @HoraEntrada   time(0) = NULL,
    @HoraSalida    time(0) = NULL,
    @AplicaHorario bit     = 1,
    @Usuario       varchar(50),
    -- Ajustes de permisos: 'clave:1,clave:0'. NULL = no se tocan; '' = solo lo de su puesto.
    @Permisos      varchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Nombre  = NULLIF(LTRIM(RTRIM(@Nombre)), '');
    SET @Paterno = NULLIF(LTRIM(RTRIM(@Paterno)), '');
    SET @Materno = NULLIF(LTRIM(RTRIM(@Materno)), '');

    IF NOT EXISTS (SELECT 1 FROM rh.Empleado e
                   JOIN rh.EmpleadoCartera ec ON ec.IdEmpleado = e.IdEmpleado AND ec.Activo = 1
                   WHERE e.IdEmpleado = @IdEmpleado AND e.Activo = 1 AND ec.IdCartera = @IdCartera)
        THROW 50030, 'El empleado no existe, está dado de baja o no pertenece a tu cartera.', 1;
    IF @Nombre IS NULL OR @Paterno IS NULL OR @Materno IS NULL
        THROW 50031, 'Captura nombre, apellido paterno y apellido materno.', 1;
    IF NOT EXISTS (SELECT 1 FROM rh.Puesto WHERE IdPuesto = @IdPuesto AND Activo = 1)
        THROW 50004, 'El puesto seleccionado no existe o esta inactivo.', 1;
    IF NOT EXISTS (SELECT 1 FROM cat.Sexo WHERE IdSexo = @IdSexo)
        THROW 50005, 'El sexo seleccionado no existe.', 1;

    -- Cambiarle el nombre no puede convertirlo en otra persona que ya existe.
    IF EXISTS (
        SELECT 1 FROM rh.Empleado e
        WHERE e.IdEmpleado <> @IdEmpleado AND e.IdEmpleadoUnificado IS NULL
          AND LTRIM(RTRIM(e.Nombre))               COLLATE Latin1_General_CI_AI = @Nombre  COLLATE Latin1_General_CI_AI
          AND LTRIM(RTRIM(e.Paterno))              COLLATE Latin1_General_CI_AI = @Paterno COLLATE Latin1_General_CI_AI
          AND LTRIM(RTRIM(ISNULL(e.Materno, ''))) COLLATE Latin1_General_CI_AI = @Materno COLLATE Latin1_General_CI_AI)
        THROW 50032, 'Ya existe otro empleado con ese nombre completo.', 1;

    EXEC rh.USP_VALIDA_HORARIO @HoraEntrada = @HoraEntrada OUTPUT, @HoraSalida = @HoraSalida OUTPUT,
                               @AplicaHorario = @AplicaHorario OUTPUT;

    DECLARE @Antes varchar(400);
    SELECT @Antes = CONCAT(e.Nombre, ' ', e.Paterno, ' ', e.Materno, ' | puesto ', e.IdPuesto, ' | sexo ', e.IdSexo,
                           ' | horario ', ISNULL(CONVERT(varchar(5), e.HoraEntrada), '--'), '-',
                           ISNULL(CONVERT(varchar(5), e.HoraSalida), '--'), CASE WHEN e.AplicaHorario = 1 THEN '' ELSE ' (no aplica)' END)
    FROM rh.Empleado e WHERE e.IdEmpleado = @IdEmpleado;

    BEGIN TRAN;

    UPDATE rh.Empleado
       SET Nombre = @Nombre, Paterno = @Paterno, Materno = @Materno,
           IdPuesto = @IdPuesto, IdSexo = @IdSexo,
           HoraEntrada = @HoraEntrada, HoraSalida = @HoraSalida, AplicaHorario = @AplicaHorario
     WHERE IdEmpleado = @IdEmpleado;

    UPDATE seg.Usuario SET IdPuesto = @IdPuesto
     WHERE IdEmpleado = @IdEmpleado AND IdPuesto <> @IdPuesto;

    IF @Permisos IS NOT NULL
    BEGIN
        DECLARE @IdUsuarioEmp int = (SELECT TOP 1 IdUsuario FROM seg.Usuario WHERE IdEmpleado = @IdEmpleado ORDER BY Activo DESC, IdUsuario);
        IF @IdUsuarioEmp IS NOT NULL
            EXEC seg.USP_GUARDA_PERMISOS @IdUsuario = @IdUsuarioEmp, @Permisos = @Permisos, @Usuario = @Usuario;
    END

    INSERT INTO log.Auditoria (Usuario, Accion, Entidad, IdEntidad, Detalle)
    VALUES (@Usuario, 'EDITA_EMPLEADO', 'rh.Empleado', CAST(@IdEmpleado AS varchar(20)),
            CONCAT('Antes: ', @Antes, ' || Después: ', @Nombre, ' ', @Paterno, ' ', @Materno,
                   ' | puesto ', @IdPuesto, ' | sexo ', @IdSexo, ' | horario ',
                   ISNULL(CONVERT(varchar(5), @HoraEntrada), '--'), '-', ISNULL(CONVERT(varchar(5), @HoraSalida), '--'),
                   CASE WHEN @AplicaHorario = 1 THEN '' ELSE ' (no aplica)' END));

    COMMIT;
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
