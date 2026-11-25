/*
  BABEL_UNIFICADA - 07. Control de migración legacy.

  Registra cada carga de datos copiada desde las bases de BABEL (CONFIGURACION_APP,
  RHBABEL y las 13 bases de cartera) hacia BABEL_UNIFICADA.

  Regla: antes de copiar ANY data legacy se debe iniciar una carga aquí y al terminar
  cerrarla con filas leídas, insertadas y omitidas. Así se puede auditar y repetir
  una carga sin duplicar registros.

  ¡No migrar contraseñas! El CRM usa PBKDF2.
*/
USE BABEL_UNIFICADA;
GO

IF SCHEMA_ID('mig') IS NULL
    EXEC('CREATE SCHEMA mig');
GO

IF OBJECT_ID('mig.ControlCarga') IS NULL
CREATE TABLE mig.ControlCarga (
    IdCarga         int            NOT NULL IDENTITY(1,1) PRIMARY KEY,
    NombreCarga     varchar(100)   NOT NULL,
    OrigenServidor  varchar(100)   NOT NULL,
    OrigenBase      varchar(100)   NOT NULL,
    Entidad         varchar(50)    NOT NULL,
    FilasLeidas     int            NOT NULL CONSTRAINT DF_ControlCarga_FilasLeidas DEFAULT (0),
    FilasInsertadas int            NOT NULL CONSTRAINT DF_ControlCarga_FilasInsertadas DEFAULT (0),
    FilasOmitidas   int            NOT NULL CONSTRAINT DF_ControlCarga_FilasOmitidas DEFAULT (0),
    UltimoIdLegacy  int            NULL,
    FechaInicio     datetime2      NOT NULL CONSTRAINT DF_ControlCarga_FechaInicio DEFAULT (SYSDATETIME()),
    FechaFin        datetime2      NULL,
    Usuario         varchar(50)    NOT NULL,
    Estatus         varchar(20)    NOT NULL CONSTRAINT DF_ControlCarga_Estatus DEFAULT ('INICIADA'),
    Detalle         varchar(max)   NULL
);
GO

IF OBJECT_ID('mig.USP_INICIA_CARGA') IS NULL
    EXEC('CREATE PROCEDURE mig.USP_INICIA_CARGA AS RETURN 0');
GO
CREATE OR ALTER PROCEDURE mig.USP_INICIA_CARGA
    @NombreCarga    varchar(100),
    @OrigenServidor varchar(100),
    @OrigenBase     varchar(100),
    @Entidad        varchar(50),
    @Usuario        varchar(50),
    @FilasLeidas    int = 0
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO mig.ControlCarga
        (NombreCarga, OrigenServidor, OrigenBase, Entidad, FilasLeidas, Usuario)
    VALUES
        (@NombreCarga, @OrigenServidor, @OrigenBase, @Entidad, @FilasLeidas, @Usuario);

    SELECT CAST(SCOPE_IDENTITY() AS int) AS IdCarga;
END
GO

IF OBJECT_ID('mig.USP_FINALIZA_CARGA') IS NULL
    EXEC('CREATE PROCEDURE mig.USP_FINALIZA_CARGA AS RETURN 0');
GO
CREATE OR ALTER PROCEDURE mig.USP_FINALIZA_CARGA
    @IdCarga        int,
    @FilasInsertadas int,
    @FilasOmitidas   int = 0,
    @UltimoIdLegacy  int = NULL,
    @Estatus         varchar(20) = 'TERMINADA',
    @Detalle         varchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE mig.ControlCarga
       SET FechaFin        = SYSDATETIME(),
           FilasInsertadas = @FilasInsertadas,
           FilasOmitidas   = @FilasOmitidas,
           UltimoIdLegacy  = @UltimoIdLegacy,
           Estatus         = @Estatus,
           Detalle         = @Detalle
     WHERE IdCarga = @IdCarga;

    SELECT @@ROWCOUNT AS Actualizadas;
END
GO

-- Verificación rápida (debe quedar vacía recién creada).
SELECT IdCarga, NombreCarga, OrigenBase, Entidad, Estatus FROM mig.ControlCarga;
GO
