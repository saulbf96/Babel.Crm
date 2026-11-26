-- =====================================================================
--  Administración de usuarios: activar/desactivar (baja lógica) y bloqueo
--  manual. Mismo alcance por campaña: solo actúa si el usuario pertenece
--  a la cartera del admin. NO se borra físicamente (se conserva historial).
-- =====================================================================
USE BABEL_UNIFICADA;
-- Obligatorio: rh.Empleado y otras tablas tienen índices filtrados (error 1934 si se crean los SP con OFF).
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- Activa o desactiva (baja lógica) al usuario. @Activo = 0 => baja; 1 => reactiva.
CREATE OR ALTER PROCEDURE seg.USP_ACTIVAR_USUARIO
    @IdUsuario int,
    @IdCartera int,
    @Activo    bit
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE u SET u.Activo = @Activo
    FROM seg.Usuario u
    WHERE u.IdUsuario = @IdUsuario
      AND EXISTS (
            SELECT 1 FROM rh.EmpleadoCartera ec
            WHERE ec.IdEmpleado = u.IdEmpleado AND ec.Activo = 1 AND ec.IdCartera = @IdCartera);

    SELECT @@ROWCOUNT AS Afectados;
END
GO

-- Bloqueo manual (sin esperar intentos fallidos).
CREATE OR ALTER PROCEDURE seg.USP_BLOQUEAR_MANUAL
    @IdUsuario int,
    @IdCartera int
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE u SET u.Bloqueado = 1
    FROM seg.Usuario u
    WHERE u.IdUsuario = @IdUsuario
      AND EXISTS (
            SELECT 1 FROM rh.EmpleadoCartera ec
            WHERE ec.IdEmpleado = u.IdEmpleado AND ec.Activo = 1 AND ec.IdCartera = @IdCartera);

    SELECT @@ROWCOUNT AS Afectados;
END
GO
