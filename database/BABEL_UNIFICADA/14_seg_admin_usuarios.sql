-- =====================================================================
--  Administración de usuarios (perfil Administrador).
--  Alcance por campaña: un admin solo ve y actúa sobre usuarios cuyo
--  empleado está asignado a la MISMA cartera (@IdCartera = cartera activa
--  de la sesión del admin). El alcance se valida SIEMPRE en estos SP.
-- =====================================================================
USE BABEL_UNIFICADA;
-- Obligatorio: rh.Empleado y otras tablas tienen índices filtrados (error 1934 si se crean los SP con OFF).
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE seg.USP_CONSULTA_USUARIOS
    @IdCartera      int,
    @SoloBloqueados bit = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        u.IdUsuario,
        u.Usuario,
        LTRIM(RTRIM(ISNULL(e.Nombre, '') + ' ' + ISNULL(e.Paterno, '') + ' ' + ISNULL(e.Materno, ''))) AS Empleado,
        ISNULL(p.Nombre, '')                         AS Puesto,
        (SELECT Nombre FROM cart.Cartera WHERE IdCartera = @IdCartera) AS Cartera,
        u.Activo,
        u.Bloqueado,
        u.DebeCambiarContrasena,
        u.UltimoAcceso
    FROM seg.Usuario u
    LEFT JOIN rh.Empleado e ON e.IdEmpleado = u.IdEmpleado
    LEFT JOIN rh.Puesto   p ON p.IdPuesto   = u.IdPuesto
    WHERE EXISTS (
            SELECT 1 FROM rh.EmpleadoCartera ec
            WHERE ec.IdEmpleado = u.IdEmpleado AND ec.Activo = 1 AND ec.IdCartera = @IdCartera)
      AND (@SoloBloqueados = 0 OR u.Bloqueado = 1)
    ORDER BY u.Bloqueado DESC, u.Usuario;
END
GO

CREATE OR ALTER PROCEDURE seg.USP_DESBLOQUEAR_USUARIO
    @IdUsuario int,
    @IdCartera int
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE u SET u.Bloqueado = 0
    FROM seg.Usuario u
    WHERE u.IdUsuario = @IdUsuario
      AND EXISTS (
            SELECT 1 FROM rh.EmpleadoCartera ec
            WHERE ec.IdEmpleado = u.IdEmpleado AND ec.Activo = 1 AND ec.IdCartera = @IdCartera);

    DECLARE @afectados int = @@ROWCOUNT;

    IF @afectados > 0
        DELETE FROM log.AccesoBloqueo
        WHERE Usuario = (SELECT Usuario FROM seg.Usuario WHERE IdUsuario = @IdUsuario);

    SELECT @afectados AS Afectados;
END
GO

CREATE OR ALTER PROCEDURE seg.USP_FORZAR_CAMBIO
    @IdUsuario int,
    @IdCartera int
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE u SET u.DebeCambiarContrasena = 1
    FROM seg.Usuario u
    WHERE u.IdUsuario = @IdUsuario
      AND EXISTS (
            SELECT 1 FROM rh.EmpleadoCartera ec
            WHERE ec.IdEmpleado = u.IdEmpleado AND ec.Activo = 1 AND ec.IdCartera = @IdCartera);

    SELECT @@ROWCOUNT AS Afectados;
END
GO

-- =====================================================================
--  Restablecer contraseña (26/11/2026): el admin genera una temporal ÚNICA
--  (la calcula y muestra el backend una sola vez). Desbloquea y obliga a
--  cambiarla al entrar. Solo usuarios de la cartera del admin.
-- =====================================================================
CREATE OR ALTER PROCEDURE seg.USP_RESTABLECER_CONTRASENA
    @IdUsuario      int,
    @IdCartera      int,
    @HashContrasena varchar(200),
    @Usuario        varchar(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (
        SELECT 1 FROM seg.Usuario u
        WHERE u.IdUsuario = @IdUsuario AND u.EsRoot = 0
          AND EXISTS (SELECT 1 FROM rh.EmpleadoCartera ec
                      WHERE ec.IdEmpleado = u.IdEmpleado AND ec.Activo = 1 AND ec.IdCartera = @IdCartera))
    BEGIN
        SELECT 0 AS Afectados;
        RETURN;
    END

    BEGIN TRAN;
    -- La contraseña anterior pasa al historial (no podrá volver a usarla).
    INSERT INTO seg.HistorialContrasena (IdUsuario, HashContrasena)
    SELECT IdUsuario, HashContrasena FROM seg.Usuario WHERE IdUsuario = @IdUsuario;

    UPDATE seg.Usuario
       SET HashContrasena = @HashContrasena,
           DebeCambiarContrasena = 1,
           Bloqueado = 0,
           FechaCambioContrasena = SYSDATETIME()
     WHERE IdUsuario = @IdUsuario;

    DELETE FROM log.AccesoBloqueo
     WHERE Usuario = (SELECT Usuario FROM seg.Usuario WHERE IdUsuario = @IdUsuario);

    INSERT INTO log.Auditoria (Usuario, Accion, Entidad, IdEntidad, Detalle)
    VALUES (@Usuario, 'RESTABLECE_CONTRASENA', 'seg.Usuario', CAST(@IdUsuario AS varchar(20)),
            'Contraseña temporal nueva (cambio obligatorio al entrar)');
    COMMIT;

    SELECT 1 AS Afectados;
END
GO
