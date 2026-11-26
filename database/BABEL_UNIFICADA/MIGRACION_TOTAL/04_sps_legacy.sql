/*
  04_sps_legacy.sql
  Capa de compatibilidad para SPs legacy usados por el aplicativo de Gestión.
  Implementa comportamiento observable contra ope.* en BABEL_UNIFICADA.
  Los SPs originales están cifrados en el remoto; las firmas se infieren de
  MDL_CONSULTAS.cs y de los contratos capturados en la memoria del proyecto.

  Nota: no todos los 80+ SPs legacy tienen contrato completo. Aquí se
  implementan los de mayor impacto operativo; los no cubiertos deben agregarse
  conforme se capture su firma/uso.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

-- Helper: resuelve IdCartera por nombre de base legacy
CREATE OR ALTER FUNCTION dbo.fn_IdCarteraPorBase(@BaseDatos varchar(100))
RETURNS tinyint
AS
BEGIN
    RETURN (
        SELECT TOP (1) IdCartera
        FROM cart.Cartera
        WHERE Activo = 1 AND UPPER(Nombre) = UPPER(LTRIM(RTRIM(@BaseDatos)))
    );
END;
GO

-- ---------------------------------------------------------------------------
-- Gestión
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.INSERTA_NEGE_GESTION
    @ID_CONTROL bigint,
    @ID_EMPLEADO smallint,
    @ID_STATUS tinyint,
    @ID_EXTENSION smallint = NULL,
    @ID_TIPO_MARCACION tinyint = NULL,
    @ID_ORIGEN tinyint = NULL,
    @ID_INTEGRACION bigint = NULL,
    @FECHA_GESTION datetime = NULL,
    @HORA_INICIO_GESTION datetime = NULL,
    @HORA_FIN_GESTION datetime = NULL,
    @TELEFONO_MARCADO varchar(30) = NULL,
    @COMENTARIO varchar(8000) = NULL,
    @TIEMPO_LLAMADA int = NULL,
    @TIEMPO_ESCRITURA int = NULL,
    @TIEMPO_MUERTO int = NULL,
    @INBOUND bit = 0,
    @BASE_DATOS varchar(100),
    @ID_HERRAMIENTA int = NULL,
    @ID_GRUPO_GESTION int = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IdCartera tinyint = dbo.fn_IdCarteraPorBase(@BASE_DATOS);
    IF @IdCartera IS NULL RETURN;

    DECLARE @IdCuenta bigint = (
        SELECT TOP (1) IdCuenta FROM ope.Cuenta
        WHERE IdCartera=@IdCartera AND IdControlLegacy=@ID_CONTROL);
    IF @IdCuenta IS NULL RETURN;

    DECLARE @IdEmpleado int = (
        SELECT TOP (1) ISNULL(e.IdEmpleadoUnificado, e.IdEmpleado)
        FROM rh.Empleado e WHERE e.IdEmpleado=@ID_EMPLEADO);
    IF @IdEmpleado IS NULL SET @IdEmpleado = @ID_EMPLEADO;

    INSERT INTO ope.Gestion (
        IdCuenta, IdCartera, IdEmpleado, IdTipoGestion, TelefonoMarcado, Comentario,
        Inbound, FechaInicio, FechaFin, TiempoLlamadaSegundos, TiempoEscrituraSegundos,
        IdIntegracionLegacy, IdRegistroLegacy)
    VALUES (
        @IdCuenta, @IdCartera, @IdEmpleado, 1,
        NULLIF(LTRIM(RTRIM(@TELEFONO_MARCADO)), ''),
        CONCAT('[Status legacy ', ISNULL(@ID_STATUS,0), '] ', ISNULL(@COMENTARIO,'')),
        ISNULL(@INBOUND,0),
        ISNULL(@HORA_INICIO_GESTION, ISNULL(@FECHA_GESTION, SYSDATETIME())),
        @HORA_FIN_GESTION,
        @TIEMPO_LLAMADA, @TIEMPO_ESCRITURA,
        @ID_INTEGRACION, NULL);
END;
GO

-- ---------------------------------------------------------------------------
-- Promesas
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.INSERTA_NEPR_PROMESAS
    @ID_CONTROL bigint,
    @ID_BASE tinyint = NULL,
    @ID_GPO_CLT tinyint = NULL,
    @ID_GESTION bigint = NULL,
    @DIA datetime = NULL,
    @MONTO decimal(18,2) = NULL,
    @LUGAR varchar(100) = NULL,
    @ID_RAZON_MORA varchar(100) = NULL,
    @ID_FUENTE_ING varchar(100) = NULL,
    @BASE_DATOS varchar(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IdCartera tinyint = dbo.fn_IdCarteraPorBase(@BASE_DATOS);
    IF @IdCartera IS NULL RETURN;
    DECLARE @IdCuenta bigint = (
        SELECT TOP (1) IdCuenta FROM ope.Cuenta WHERE IdCartera=@IdCartera AND IdControlLegacy=@ID_CONTROL);
    IF @IdCuenta IS NULL RETURN;

    DECLARE @IdGestion bigint = NULL;
    IF @ID_GESTION IS NOT NULL
        SELECT TOP (1) @IdGestion = IdGestion FROM ope.Gestion
        WHERE IdCartera=@IdCartera AND IdRegistroLegacy=@ID_GESTION;

    INSERT INTO ope.Promesa (IdCuenta, IdCartera, IdGestion, Monto, FechaPromesa, LugarPago, FuenteIngreso, RazonMora, Estatus)
    VALUES (@IdCuenta, @IdCartera, @IdGestion, ISNULL(@MONTO,0),
            CAST(ISNULL(@DIA, GETDATE()) AS date),
            NULLIF(LTRIM(RTRIM(@LUGAR)), ''),
            NULLIF(LTRIM(RTRIM(@ID_FUENTE_ING)), ''),
            NULLIF(LTRIM(RTRIM(@ID_RAZON_MORA)), ''),
            'PENDIENTE');
END;
GO

-- ---------------------------------------------------------------------------
-- Teléfonos
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.INSERTA_NEBT_BASE_TELEFONICA
    @ID_CONTROL bigint,
    @TELEFONO varchar(30),
    @TIPO_TEL varchar(20) = NULL,
    @LADA smallint = NULL,
    @PREFIJO smallint = NULL,
    @ACTIVO bit = 1,
    @BASE_DATOS varchar(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IdCartera tinyint = dbo.fn_IdCarteraPorBase(@BASE_DATOS);
    IF @IdCartera IS NULL RETURN;
    DECLARE @IdCuenta bigint = (
        SELECT TOP (1) IdCuenta FROM ope.Cuenta WHERE IdCartera=@IdCartera AND IdControlLegacy=@ID_CONTROL);
    IF @IdCuenta IS NULL RETURN;

    IF NOT EXISTS (SELECT 1 FROM ope.Telefono WHERE IdCartera=@IdCartera AND IdCuenta=@IdCuenta AND Numero=@TELEFONO)
        INSERT INTO ope.Telefono (IdCuenta, IdCartera, Numero, Tipo, Origen, Activo)
        VALUES (@IdCuenta, @IdCartera, @TELEFONO, NULLIF(@TIPO_TEL,''), CONCAT('Lada ',ISNULL(@LADA,0),' / Prefijo ',ISNULL(@PREFIJO,0)), ISNULL(@ACTIVO,1));
END;
GO

CREATE OR ALTER PROCEDURE dbo.CONSULTA_NEBT_BASE_TELEFONICA
    @ID_CONTROL bigint,
    @BASE_DATOS varchar(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IdCartera tinyint = dbo.fn_IdCarteraPorBase(@BASE_DATOS);
    SELECT t.IdTelefono, t.Numero, t.Tipo, t.Origen, t.Activo, t.FechaRegistro
    FROM ope.Telefono t
    JOIN ope.Cuenta c ON c.IdCuenta=t.IdCuenta
    WHERE c.IdCartera=@IdCartera AND c.IdControlLegacy=@ID_CONTROL
    ORDER BY t.IdTelefono DESC;
END;
GO

-- ---------------------------------------------------------------------------
-- Demográficos
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.CONSULTA_NEDE_DEMOGRAFICOS
    @ID_CONTROL bigint,
    @BASE_DATOS varchar(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IdCartera tinyint = dbo.fn_IdCarteraPorBase(@BASE_DATOS);
    SELECT d.IdDemografico, d.Calle, d.Colonia, d.CodigoPostal, d.Delegacion, d.Estado, d.Telefono, d.Email, d.FechaRegistro
    FROM ope.Demografico d
    JOIN ope.Cuenta c ON c.IdCuenta=d.IdCuenta
    WHERE c.IdCartera=@IdCartera AND c.IdControlLegacy=@ID_CONTROL
    ORDER BY d.IdDemografico DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.INSERTA_NEDE_DEMOGRAFICOS
    @ID_CONTROL bigint,
    @CALLE varchar(200) = NULL,
    @COLONIA varchar(150) = NULL,
    @CP varchar(10) = NULL,
    @DEL_MUN varchar(150) = NULL,
    @MUNICIPIO varchar(150) = NULL,
    @TELEFONO varchar(30) = NULL,
    @EMAIL varchar(150) = NULL,
    @BASE_DATOS varchar(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IdCartera tinyint = dbo.fn_IdCarteraPorBase(@BASE_DATOS);
    IF @IdCartera IS NULL RETURN;
    DECLARE @IdCuenta bigint = (
        SELECT TOP (1) IdCuenta FROM ope.Cuenta WHERE IdCartera=@IdCartera AND IdControlLegacy=@ID_CONTROL);
    IF @IdCuenta IS NULL RETURN;
    INSERT INTO ope.Demografico (IdCuenta, IdCartera, Calle, Colonia, CodigoPostal, Delegacion, Estado, Telefono, Email)
    VALUES (@IdCuenta, @IdCartera, NULLIF(@CALLE,''), NULLIF(@COLONIA,''), NULLIF(@CP,''),
            NULLIF(@DEL_MUN,''), NULLIF(@MUNICIPIO,''), NULLIF(@TELEFONO,''), NULLIF(@EMAIL,''));
END;
GO

-- ---------------------------------------------------------------------------
-- Mora/Fuente ingreso / Notas / Bloc
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.INSERTA_NEMF_MORA_FUENTE_INGRESO
    @ID_CONTROL bigint,
    @ID_GESTION bigint = NULL,
    @FUENTE_INGRESO varchar(100) = NULL,
    @RAZON_MORA varchar(100) = NULL,
    @INTENCION varchar(100) = NULL,
    @COMENTARIO nvarchar(max) = NULL,
    @BASE_DATOS varchar(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IdCartera tinyint = dbo.fn_IdCarteraPorBase(@BASE_DATOS);
    IF @IdCartera IS NULL RETURN;
    DECLARE @IdCuenta bigint = (
        SELECT TOP (1) IdCuenta FROM ope.Cuenta WHERE IdCartera=@IdCartera AND IdControlLegacy=@ID_CONTROL);
    IF @IdCuenta IS NULL RETURN;
    DECLARE @IdGestion bigint = NULL;
    IF @ID_GESTION IS NOT NULL
        SELECT TOP (1) @IdGestion=IdGestion FROM ope.Gestion WHERE IdCartera=@IdCartera AND IdRegistroLegacy=@ID_GESTION;
    INSERT INTO ope.MoraFuenteIngreso (IdCuenta, IdCartera, IdGestion, FuenteIngreso, RazonMora, Intencion, Comentario)
    VALUES (@IdCuenta, @IdCartera, @IdGestion, NULLIF(@FUENTE_INGRESO,''), NULLIF(@RAZON_MORA,''), NULLIF(@INTENCION,''), NULLIF(@COMENTARIO,''));
END;
GO

CREATE OR ALTER PROCEDURE dbo.CONSULTA_NEBN_BLOC_NOTAS
    @ID_EMPLEADO int,
    @BASE_DATOS varchar(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IdCartera tinyint = dbo.fn_IdCarteraPorBase(@BASE_DATOS);
    DECLARE @IdEmpleado int = (SELECT TOP (1) ISNULL(IdEmpleadoUnificado,IdEmpleado) FROM rh.Empleado WHERE IdEmpleado=@ID_EMPLEADO);
    SELECT TOP (1) Texto, FechaRegistro FROM ope.BlocNota
    WHERE IdCartera=@IdCartera AND IdEmpleado=ISNULL(@IdEmpleado,@ID_EMPLEADO)
    ORDER BY FechaRegistro DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.ACTUALIZA_NEBN_BLOC_NOTAS
    @ID_EMPLEADO int,
    @TEXTO nvarchar(max),
    @BASE_DATOS varchar(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IdCartera tinyint = dbo.fn_IdCarteraPorBase(@BASE_DATOS);
    DECLARE @IdEmpleado int = (SELECT TOP (1) ISNULL(IdEmpleadoUnificado,IdEmpleado) FROM rh.Empleado WHERE IdEmpleado=@ID_EMPLEADO);
    SET @IdEmpleado = ISNULL(@IdEmpleado, @ID_EMPLEADO);
    IF EXISTS (SELECT 1 FROM ope.BlocNota WHERE IdCartera=@IdCartera AND IdEmpleado=@IdEmpleado)
        UPDATE ope.BlocNota SET Texto=@TEXTO, FechaRegistro=SYSDATETIME() WHERE IdCartera=@IdCartera AND IdEmpleado=@IdEmpleado;
    ELSE
        INSERT INTO ope.BlocNota (IdCartera, IdEmpleado, Texto) VALUES (@IdCartera, @IdEmpleado, @TEXTO);
END;
GO

PRINT '04_sps_legacy.sql aplicado (capa de compatibilidad principal).';
