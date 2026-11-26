-- =====================================================================
--  Administración de usuarios (perfil Administrador).
--  Alcance por campaña: un admin solo ve y actúa sobre usuarios cuyo
--  empleado está asignado a la MISMA cartera (@IdCartera = cartera activa
--  de la sesión del admin). El alcance se valida SIEMPRE en estos SP.
-- =====================================================================
USE BABEL_UNIFICADA;
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
