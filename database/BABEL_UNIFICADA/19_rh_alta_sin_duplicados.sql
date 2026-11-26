-- =====================================================================
--  Alta de empleados SIN duplicados.
--
--  En BABEL se da de alta OTRA VEZ a la misma persona por cada cartera o
--  reingreso (al 26/11/2026: 40 personas repetidas, 47 registros de más,
--  desde 2024 y sigue pasando). En el CRM una persona = un empleado:
--    - cartera activa: rh.EmpleadoCartera (una sola, índice UX_EmpleadoCartera_Activa)
--    - otras carteras: rh.EmpleadoCarteraAcceso (equivale a REUM_USUARIO_MULTI_CARTERA)
--
--  Antes del alta se buscan coincidencias por nombre completo (sin importar
--  mayúsculas ni acentos). Si existe, la pantalla ofrece moverlo o darle
--  acceso a la cartera, o reactivarlo si está de baja. Solo si el admin
--  confirma que es OTRA persona (homónimo) se da de alta.
--  El alta (rh.USP_ALTA_EMPLEADO, script 03) también lo valida en el servidor.
--  Idempotente.
-- =====================================================================
USE BABEL_UNIFICADA;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE rh.USP_BUSCA_DUPLICADOS
    @Nombre    varchar(100),
    @Paterno   varchar(100),
    @Materno   varchar(100) = NULL,
    @IdCartera tinyint
AS
BEGIN
    SET NOCOUNT ON;

    SET @Nombre  = LTRIM(RTRIM(ISNULL(@Nombre, '')));
    SET @Paterno = LTRIM(RTRIM(ISNULL(@Paterno, '')));
    SET @Materno = LTRIM(RTRIM(ISNULL(@Materno, '')));

    SELECT
        e.IdEmpleado,
        LTRIM(RTRIM(CONCAT(e.Nombre, ' ', e.Paterno, ' ', ISNULL(e.Materno, '')))) AS NombreCompleto,
        p.Nombre AS Puesto,
        e.Activo,
        e.FechaIngreso,
        c.Nombre AS CarteraActiva,
        CAST(CASE WHEN ec.IdCartera = @IdCartera THEN 1 ELSE 0 END AS bit) AS EnEstaCartera,
        CAST(CASE WHEN EXISTS (SELECT 1 FROM rh.EmpleadoCarteraAcceso a
                               WHERE a.IdEmpleado = e.IdEmpleado AND a.IdCartera = @IdCartera AND a.Activo = 1)
                  THEN 1 ELSE 0 END AS bit) AS TieneAcceso,
        u.Usuario
    FROM rh.Empleado e
    JOIN rh.Puesto p ON p.IdPuesto = e.IdPuesto
    LEFT JOIN rh.EmpleadoCartera ec ON ec.IdEmpleado = e.IdEmpleado AND ec.Activo = 1
    LEFT JOIN cart.Cartera c ON c.IdCartera = ec.IdCartera
    LEFT JOIN seg.Usuario u ON u.IdEmpleado = e.IdEmpleado
    WHERE e.IdEmpleadoUnificado IS NULL   -- solo el registro que representa a la persona
      AND LTRIM(RTRIM(e.Nombre))               COLLATE Latin1_General_CI_AI = @Nombre  COLLATE Latin1_General_CI_AI
      AND LTRIM(RTRIM(e.Paterno))              COLLATE Latin1_General_CI_AI = @Paterno COLLATE Latin1_General_CI_AI
      AND LTRIM(RTRIM(ISNULL(e.Materno, ''))) COLLATE Latin1_General_CI_AI = @Materno COLLATE Latin1_General_CI_AI
    ORDER BY e.Activo DESC, e.FechaIngreso, e.IdEmpleado;
END
GO

-- ---------------------------------------------------------------------
--  Darle acceso a otra cartera a un empleado activo (sin moverlo):
--  podrá entrar a ella con "Cambia cartera".
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE rh.USP_DAR_ACCESO_CARTERA
    @IdEmpleado int,
    @IdCartera  tinyint,
    @Usuario    varchar(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM rh.Empleado WHERE IdEmpleado = @IdEmpleado AND Activo = 1)
        THROW 50020, 'El empleado no existe o está dado de baja.', 1;
    IF NOT EXISTS (SELECT 1 FROM cart.Cartera WHERE IdCartera = @IdCartera AND Activo = 1)
        THROW 50021, 'La cartera no existe o está inactiva.', 1;
    IF EXISTS (SELECT 1 FROM rh.EmpleadoCartera WHERE IdEmpleado = @IdEmpleado AND IdCartera = @IdCartera AND Activo = 1)
        THROW 50022, 'El empleado ya pertenece a esta cartera.', 1;

    BEGIN TRAN;

    UPDATE rh.EmpleadoCarteraAcceso SET Activo = 1
     WHERE IdEmpleado = @IdEmpleado AND IdCartera = @IdCartera;

    IF @@ROWCOUNT = 0
        INSERT INTO rh.EmpleadoCarteraAcceso (IdEmpleado, IdCartera, Activo)
        VALUES (@IdEmpleado, @IdCartera, 1);

    INSERT INTO log.Auditoria (Usuario, Accion, Entidad, IdEntidad, Detalle)
    VALUES (@Usuario, 'ACCESO_CARTERA', 'rh.Empleado', CAST(@IdEmpleado AS varchar(20)),
            CONCAT('Acceso a cartera ', @IdCartera, ' (en lugar de alta duplicada)'));

    COMMIT;
END
GO
