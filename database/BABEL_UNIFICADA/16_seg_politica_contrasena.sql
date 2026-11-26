-- =====================================================================
--  Política de contraseñas del CRM (BABEL no tenía ninguna).
--   1. No se puede reutilizar la contraseña actual ni las últimas N
--      (historial de hashes PBKDF2; la comparación la hace el backend,
--      porque cada hash lleva su propia sal).
--   2. La contraseña vence a los N días: al vencer, el login exige cambio.
--  Los valores (N recordadas, días de vigencia) viven en el backend
--  (PoliticaContrasena) y llegan como parámetros.
--  Idempotente: se puede volver a correr después de una re-migración.
-- =====================================================================
USE BABEL_UNIFICADA;
-- Obligatorio: rh.Empleado y otras tablas tienen índices filtrados (error 1934 si se crean los SP con OFF).
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- Fecha del último cambio de contraseña (base del vencimiento).
IF COL_LENGTH('seg.Usuario', 'FechaCambioContrasena') IS NULL
BEGIN
    ALTER TABLE seg.Usuario ADD FechaCambioContrasena datetime2(0) NULL;
END
GO

-- Usuarios existentes: se cuenta desde su alta para no vencerlos de golpe.
UPDATE seg.Usuario
   SET FechaCambioContrasena = FechaRegistro
 WHERE FechaCambioContrasena IS NULL;
GO

IF OBJECT_ID('seg.HistorialContrasena') IS NULL
CREATE TABLE seg.HistorialContrasena (
    IdHistorial     int           NOT NULL IDENTITY(1,1) PRIMARY KEY,
    IdUsuario       int           NOT NULL,
    HashContrasena  varchar(200)  NOT NULL,   -- hash ANTERIOR (nunca la contraseña en claro)
    FechaRegistro   datetime2(0)  NOT NULL CONSTRAINT DF_HistorialContrasena_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT FK_HistorialContrasena_Usuario FOREIGN KEY (IdUsuario) REFERENCES seg.Usuario (IdUsuario)
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_HistorialContrasena_Usuario')
    CREATE INDEX IX_HistorialContrasena_Usuario
        ON seg.HistorialContrasena (IdUsuario, IdHistorial DESC);
GO

-- ---------------------------------------------------------------------
--  Hashes contra los que NO puede coincidir la contraseña nueva:
--  el actual (EsActual = 1) y los últimos @Recordadas del historial.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE seg.USP_CONSULTA_HASHES_RECIENTES
    @IdUsuario  int,
    @Recordadas int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CAST(1 AS bit) AS EsActual, u.HashContrasena
    FROM seg.Usuario u
    WHERE u.IdUsuario = @IdUsuario
    UNION ALL
    SELECT CAST(0 AS bit), h.HashContrasena
    FROM (
        SELECT TOP (@Recordadas) HashContrasena
        FROM seg.HistorialContrasena
        WHERE IdUsuario = @IdUsuario
        ORDER BY IdHistorial DESC
    ) h;
END
GO

-- ---------------------------------------------------------------------
--  Cambio de contraseña: guarda el hash anterior en el historial,
--  pone el nuevo, baja la bandera y reinicia la vigencia.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE seg.USP_CAMBIAR_CONTRASENA
    @IdUsuario      int,
    @HashContrasena varchar(200)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRAN;

    INSERT INTO seg.HistorialContrasena (IdUsuario, HashContrasena)
    SELECT IdUsuario, HashContrasena
    FROM seg.Usuario
    WHERE IdUsuario = @IdUsuario;

    UPDATE seg.Usuario
       SET HashContrasena        = @HashContrasena,
           DebeCambiarContrasena = 0,
           FechaCambioContrasena = SYSDATETIME()
     WHERE IdUsuario = @IdUsuario;

    COMMIT;
END
GO

-- ---------------------------------------------------------------------
--  ¿Debe cambiar contraseña al entrar? Por usuario (no por empleado:
--  el ADMIN de arranque no tiene empleado y antes nunca se le exigía).
--  Motivo: 'FORZADO' (lo pidió un admin / alta) o 'VENCIDA' (> @DiasVigencia).
--  Sin renglones = no debe cambiar.
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE seg.USP_ESTADO_CONTRASENA
    @IdUsuario    int,
    @DiasVigencia int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CASE WHEN u.DebeCambiarContrasena = 1 THEN 'FORZADO' ELSE 'VENCIDA' END AS Motivo
    FROM seg.Usuario u
    WHERE u.IdUsuario = @IdUsuario
      AND u.Activo = 1
      AND (   u.DebeCambiarContrasena = 1
           OR DATEDIFF(DAY, ISNULL(u.FechaCambioContrasena, u.FechaRegistro), SYSDATETIME()) >= @DiasVigencia);
END
GO
