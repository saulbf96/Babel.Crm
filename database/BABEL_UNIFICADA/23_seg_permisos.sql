-- =====================================================================
--  Permisos por opción de menú (26/11/2026).
--
--  Reglas del usuario:
--   - Perfil ROOT: el primer usuario (hoy ADMIN). Tiene TODO; no se le
--     puede quitar el ROOT.
--   - Solo administradores (o ROOT) dan permisos, y solo los que ellos tienen.
--   - Nadie cambia SUS PROPIOS permisos (lo hace otro admin); ROOT sí puede.
--   - Se da un menú completo o solo algunas opciones de cada menú.
--
--  Modelo: permisos efectivos = base del puesto (perfil) + ajustes por
--  usuario (seg.UsuarioPermiso: Concedido 1 = se agrega, 0 = se quita).
--  ROOT: base = todas las opciones. La clave es la de CatalogoMenu (backend).
--  Idempotente. Correr con: sqlcmd -I -f 65001
-- =====================================================================
USE BABEL_UNIFICADA;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF COL_LENGTH('seg.Usuario', 'EsRoot') IS NULL
    ALTER TABLE seg.Usuario ADD EsRoot bit NOT NULL CONSTRAINT DF_Usuario_EsRoot DEFAULT (0);
GO

-- El primer usuario es ROOT (solo si todavía no hay ninguno).
IF NOT EXISTS (SELECT 1 FROM seg.Usuario WHERE EsRoot = 1)
    UPDATE seg.Usuario SET EsRoot = 1 WHERE IdUsuario = (SELECT MIN(IdUsuario) FROM seg.Usuario);
GO

IF OBJECT_ID('seg.UsuarioPermiso') IS NULL
CREATE TABLE seg.UsuarioPermiso (
    IdUsuario       int          NOT NULL,
    Clave           varchar(60)  NOT NULL,   -- clave de CatalogoMenu (ej. 'bajas', 'gestion-nueva')
    Concedido       bit          NOT NULL,   -- 1 = se agrega a lo de su puesto, 0 = se le quita
    FechaRegistro   datetime2(0) NOT NULL CONSTRAINT DF_UsuarioPermiso_Fecha DEFAULT (SYSDATETIME()),
    UsuarioRegistro varchar(50)  NOT NULL,
    CONSTRAINT PK_UsuarioPermiso PRIMARY KEY (IdUsuario, Clave),
    CONSTRAINT FK_UsuarioPermiso_Usuario FOREIGN KEY (IdUsuario) REFERENCES seg.Usuario (IdUsuario)
);
GO

-- Ajustes de un usuario (login).
CREATE OR ALTER PROCEDURE seg.USP_CONSULTA_PERMISOS
    @IdUsuario int
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Clave, Concedido FROM seg.UsuarioPermiso WHERE IdUsuario = @IdUsuario;
END
GO

-- Para Editar empleado: su usuario, si es ROOT, su puesto y sus ajustes
-- (siempre regresa al menos un renglón si el empleado tiene usuario).
CREATE OR ALTER PROCEDURE seg.USP_CONSULTA_PERMISOS_EMPLEADO
    @IdEmpleado int
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.IdUsuario, u.EsRoot, u.IdPuesto, p.Clave, p.Concedido
    FROM seg.Usuario u
    LEFT JOIN seg.UsuarioPermiso p ON p.IdUsuario = u.IdUsuario
    WHERE u.IdEmpleado = @IdEmpleado;
END
GO

-- Reemplaza los ajustes de un usuario. @Permisos = 'clave:1,clave:0' (vacío = solo lo de su puesto).
CREATE OR ALTER PROCEDURE seg.USP_GUARDA_PERMISOS
    @IdUsuario int,
    @Permisos  varchar(max),
    @Usuario   varchar(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRAN;
    DELETE FROM seg.UsuarioPermiso WHERE IdUsuario = @IdUsuario;

    INSERT INTO seg.UsuarioPermiso (IdUsuario, Clave, Concedido, UsuarioRegistro)
    SELECT @IdUsuario,
           LEFT(LTRIM(RTRIM(LEFT(value, CHARINDEX(':', value) - 1))), 60),
           CASE WHEN RIGHT(value, 1) = '1' THEN 1 ELSE 0 END,
           @Usuario
    FROM STRING_SPLIT(ISNULL(@Permisos, ''), ',')
    WHERE CHARINDEX(':', value) > 1;

    INSERT INTO log.Auditoria (Usuario, Accion, Entidad, IdEntidad, Detalle)
    VALUES (@Usuario, 'PERMISOS_USUARIO', 'seg.Usuario', CAST(@IdUsuario AS varchar(20)),
            CONCAT('Ajustes de permisos: ', NULLIF(@Permisos, ''), CASE WHEN ISNULL(@Permisos, '') = '' THEN '(solo los de su puesto)' ELSE '' END));
    COMMIT;
END
GO
