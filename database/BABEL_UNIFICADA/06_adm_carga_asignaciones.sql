/*
  BABEL_UNIFICADA - 06. Carga de asignaciones (staging).

  El .exe lee un Excel de \\10.80.5.189\BANCO AZTECA\ASIGNACIONES y ejecuta
  ADMINISTRA_APP.DBO.PROCESO_ASIGNACION con uno de estos procesos:

    1 CUADRE
    2 ACTUALIZACION
    3 RETIRO
    4 INSERCION / REASIGNACION

  El T-SQL de PROCESO_ASIGNACION esta cifrado en el servidor y aun no se ha
  recuperado. Por eso aqui se deja SOLO el staging (recibir, guardar y auditar
  el archivo). La logica de aplicacion se implementara cuando se tenga el
  contrato exacto de columnas del Excel y el comportamiento del SP.

  Importante: no se guarda el archivo binario en la base; se guarda la ruta o
  el nombre y el contenido de cada fila en JSON para validacion y auditoria.
*/
USE BABEL_UNIFICADA;
GO

IF OBJECT_ID('adm.ProcesoAsignacion') IS NULL
CREATE TABLE adm.ProcesoAsignacion (
    IdProceso  tinyint      NOT NULL PRIMARY KEY,
    Nombre     varchar(50)  NOT NULL,
    Descripcion varchar(200) NULL,
    Activo     bit          NOT NULL CONSTRAINT DF_ProcesoAsignacion_Activo DEFAULT (1)
);
GO

INSERT INTO adm.ProcesoAsignacion (IdProceso, Nombre, Descripcion)
SELECT v.IdProceso, v.Nombre, v.Descripcion
FROM (VALUES
    (1, 'CUADRE',                  'Cuadre de cartera contra el archivo'),
    (2, 'ACTUALIZACION',           'Actualizacion de datos existentes'),
    (3, 'RETIRO',                  'Retiro de cuentas o asignaciones'),
    (4, 'INSERCION / REASIGNACION','Insercion o reasignacion de cuentas')
) AS v (IdProceso, Nombre, Descripcion)
WHERE NOT EXISTS (SELECT 1 FROM adm.ProcesoAsignacion x WHERE x.IdProceso = v.IdProceso);
GO

IF OBJECT_ID('adm.CargaAsignacion') IS NULL
CREATE TABLE adm.CargaAsignacion (
    IdCarga          int            NOT NULL IDENTITY(1,1) PRIMARY KEY,
    IdCartera        tinyint        NOT NULL,
    Proceso          tinyint        NOT NULL,
    NombreArchivo    nvarchar(260)  NOT NULL,
    RutaArchivo      nvarchar(500)  NULL,
    Estatus          varchar(20)    NOT NULL CONSTRAINT DF_CargaAsignacion_Estatus DEFAULT ('RECIBIDA'),
    TotalRegistros   int            NOT NULL CONSTRAINT DF_CargaAsignacion_Total DEFAULT (0),
    Procesados       int            NOT NULL CONSTRAINT DF_CargaAsignacion_Procesados DEFAULT (0),
    Errores          int            NOT NULL CONSTRAINT DF_CargaAsignacion_Errores DEFAULT (0),
    Mensaje          nvarchar(1000) NULL,
    IdUsuario        int            NULL,
    Usuario          varchar(50)    NULL,
    FechaInicio      datetime2(0)   NOT NULL CONSTRAINT DF_CargaAsignacion_Inicio DEFAULT (SYSDATETIME()),
    FechaFin         datetime2(0)   NULL,
    CONSTRAINT FK_CargaAsignacion_Cartera FOREIGN KEY (IdCartera) REFERENCES cart.Cartera (IdCartera),
    CONSTRAINT FK_CargaAsignacion_Proceso FOREIGN KEY (Proceso)   REFERENCES adm.ProcesoAsignacion (IdProceso)
);
GO

IF OBJECT_ID('adm.CargaAsignacionDetalle') IS NULL
CREATE TABLE adm.CargaAsignacionDetalle (
    IdDetalle   bigint        NOT NULL IDENTITY(1,1) PRIMARY KEY,
    IdCarga     int           NOT NULL,
    NumeroFila  int           NOT NULL,
    Contenido   nvarchar(max) NULL,   -- JSON con la fila cruda del Excel
    Estatus     varchar(20)   NOT NULL CONSTRAINT DF_CargaDetalle_Estatus DEFAULT ('PENDIENTE'),
    Error       nvarchar(500) NULL,
    CONSTRAINT FK_CargaDetalle_Carga FOREIGN KEY (IdCarga) REFERENCES adm.CargaAsignacion (IdCarga)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CargaDetalle_Carga' AND object_id = OBJECT_ID('adm.CargaAsignacionDetalle'))
    CREATE INDEX IX_CargaDetalle_Carga ON adm.CargaAsignacionDetalle (IdCarga, NumeroFila);
GO

CREATE OR ALTER PROCEDURE adm.USP_CONSULTA_PROCESOS
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdProceso, Nombre, Descripcion FROM adm.ProcesoAsignacion WHERE Activo = 1 ORDER BY IdProceso;
END
GO

CREATE OR ALTER PROCEDURE adm.USP_CREA_CARGA
    @IdCartera     tinyint,
    @Proceso       tinyint,
    @NombreArchivo nvarchar(260),
    @RutaArchivo   nvarchar(500) = NULL,
    @IdUsuario     int = NULL,
    @Usuario       varchar(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM cart.Cartera WHERE IdCartera = @IdCartera AND Activo = 1)
        THROW 50020, 'La cartera seleccionada no existe o esta inactiva.', 1;
    IF NOT EXISTS (SELECT 1 FROM adm.ProcesoAsignacion WHERE IdProceso = @Proceso AND Activo = 1)
        THROW 50021, 'El proceso seleccionado no existe o esta inactivo.', 1;

    INSERT INTO adm.CargaAsignacion (IdCartera, Proceso, NombreArchivo, RutaArchivo, IdUsuario, Usuario)
    VALUES (@IdCartera, @Proceso, @NombreArchivo, @RutaArchivo, @IdUsuario, @Usuario);

    DECLARE @IdCarga int = CAST(SCOPE_IDENTITY() AS int);

    INSERT INTO log.Auditoria (Usuario, Accion, Entidad, IdEntidad, Detalle)
    VALUES (@Usuario, 'CREA_CARGA_ASIGNACION', 'adm.CargaAsignacion', CAST(@IdCarga AS varchar(20)),
            CONCAT('Archivo: ', @NombreArchivo, '; cartera: ', @IdCartera, '; proceso: ', @Proceso));

    SELECT @IdCarga AS IdCarga, 'Carga recibida. Pendiente de validacion.' AS Mensaje;
END
GO

CREATE OR ALTER PROCEDURE adm.USP_CONSULTA_CARGAS
    @IdCartera tinyint = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ca.IdCarga,
        ca.IdCartera,
        c.Nombre AS Cartera,
        ca.Proceso,
        pa.Nombre AS ProcesoNombre,
        ca.NombreArchivo,
        ca.Estatus,
        ca.TotalRegistros,
        ca.Procesados,
        ca.Errores,
        ca.Mensaje,
        ca.Usuario,
        ca.FechaInicio,
        ca.FechaFin
    FROM adm.CargaAsignacion ca
    INNER JOIN cart.Cartera c          ON c.IdCartera = ca.IdCartera
    INNER JOIN adm.ProcesoAsignacion pa ON pa.IdProceso = ca.Proceso
    WHERE (@IdCartera IS NULL OR ca.IdCartera = @IdCartera)
    ORDER BY ca.IdCarga DESC;
END
GO

CREATE OR ALTER PROCEDURE adm.USP_AGREGA_DETALLE
    @IdCarga    int,
    @NumeroFila int,
    @Contenido  nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM adm.CargaAsignacion WHERE IdCarga = @IdCarga)
        THROW 50022, 'La carga no existe.', 1;

    INSERT INTO adm.CargaAsignacionDetalle (IdCarga, NumeroFila, Contenido)
    VALUES (@IdCarga, @NumeroFila, @Contenido);

    SELECT CAST(SCOPE_IDENTITY() AS bigint) AS IdDetalle;
END
GO

-- Inserta en una sola llamada todas las filas recibidas como arreglo JSON.
CREATE OR ALTER PROCEDURE adm.USP_AGREGA_DETALLE_LOTE
    @IdCarga   int,
    @FilasJson nvarchar(max)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM adm.CargaAsignacion WHERE IdCarga = @IdCarga)
        THROW 50022, 'La carga no existe.', 1;

    IF @FilasJson IS NULL OR ISJSON(@FilasJson) = 0
        THROW 50023, 'Las filas de la carga no tienen un formato valido.', 1;

    INSERT INTO adm.CargaAsignacionDetalle (IdCarga, NumeroFila, Contenido)
    SELECT @IdCarga, CAST(j.[key] AS int) + 1, j.[value]
    FROM OPENJSON(@FilasJson) j;

    SELECT @@ROWCOUNT AS Insertados;
END
GO

CREATE OR ALTER PROCEDURE adm.USP_ACTUALIZA_CARGA
    @IdCarga        int,
    @Estatus        varchar(20),
    @TotalRegistros int = NULL,
    @Procesados     int = NULL,
    @Errores        int = NULL,
    @Mensaje        nvarchar(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE adm.CargaAsignacion
       SET Estatus        = @Estatus,
           TotalRegistros = ISNULL(@TotalRegistros, TotalRegistros),
           Procesados     = ISNULL(@Procesados, Procesados),
           Errores        = ISNULL(@Errores, Errores),
           Mensaje        = ISNULL(@Mensaje, Mensaje),
           FechaFin       = CASE WHEN @Estatus IN ('APLICADA', 'ERROR', 'CANCELADA') THEN SYSDATETIME() ELSE FechaFin END
     WHERE IdCarga = @IdCarga;

    SELECT @@ROWCOUNT AS Actualizados;
END
GO

PRINT 'Modulo adm listo (staging de carga de asignaciones; proceso pendiente de descifrar).';
GO
