/*
  BABEL_CRM - 03. Modulo de Seguridad (login propio del CRM).
  El login viejo de BABEL usa procedimientos CIFRADOS y una llave secreta que ya no se tiene,
  y las contrasenas viejas no se pueden leer: por eso el CRM administra sus propias credenciales
  con hash moderno PBKDF2 (nunca se guarda la contrasena en claro).
  Ejecutar despues de 02_rh_empleados.sql.
*/
USE BABEL_CRM;
GO

IF OBJECT_ID('seg.Usuario') IS NULL
CREATE TABLE seg.Usuario (
    IdUsuario              int          NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Usuario                varchar(50)  NOT NULL UNIQUE,
    HashContrasena         varchar(200) NOT NULL,   -- formato PBKDF2$SHA256$iter$salt$key
    IdEmpleado             int          NULL,        -- enlace opcional a rh.Empleado
    IdCliente              int          NOT NULL,
    IdPuesto               tinyint      NOT NULL,     -- define el perfil (seg: PuestosPorPerfil)
    IdDepartamento         tinyint      NOT NULL,
    Activo                 bit          NOT NULL CONSTRAINT DF_Usuario_Activo DEFAULT(1),
    Bloqueado              bit          NOT NULL CONSTRAINT DF_Usuario_Bloqueado DEFAULT(0),
    DebeCambiarContrasena  bit          NOT NULL CONSTRAINT DF_Usuario_Cambiar DEFAULT(1),
    FechaRegistro          datetime2(0) NOT NULL CONSTRAINT DF_Usuario_Fecha DEFAULT(SYSUTCDATETIME())
);
GO

-- Bitacora propia de bloqueos (reemplaza LOGSSISTEMA, a la que no tenemos acceso).
IF OBJECT_ID('log.AccesoBloqueo') IS NULL
CREATE TABLE log.AccesoBloqueo (
    IdBloqueo   bigint        NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Usuario     varchar(50)   NOT NULL,
    Ip          varchar(45)   NULL,
    Equipo      varchar(100)  NULL,
    Intentos    tinyint       NOT NULL,
    Fecha       datetime2(0)  NOT NULL CONSTRAINT DF_Bloqueo_Fecha DEFAULT(SYSUTCDATETIME())
);
GO

-- Devuelve los datos del usuario (incluye el hash para que el backend valide la contrasena).
CREATE OR ALTER PROCEDURE seg.USP_CONSULTA_USUARIO
    @Usuario varchar(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.IdUsuario, u.Usuario, u.HashContrasena, ISNULL(u.IdEmpleado, u.IdUsuario) AS IdEmpleado,
           u.IdCliente, cli.Nombre AS Cliente, u.IdPuesto, u.IdDepartamento,
           u.Activo, u.Bloqueado, u.DebeCambiarContrasena
    FROM seg.Usuario u
    JOIN seg.Cliente cli ON cli.IdCliente = u.IdCliente
    WHERE u.Usuario = @Usuario;
END
GO

-- Indica si el empleado/usuario tiene pendiente el cambio de contrasena.
CREATE OR ALTER PROCEDURE seg.USP_DEBE_CAMBIAR
    @IdEmpleado int
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 1 AS Pendiente
    FROM seg.Usuario
    WHERE ISNULL(IdEmpleado, IdUsuario) = @IdEmpleado AND DebeCambiarContrasena = 1;
END
GO

-- Bloquea al usuario por intentos fallidos y registra el bloqueo.
CREATE OR ALTER PROCEDURE seg.USP_BLOQUEAR_USUARIO
    @Usuario  varchar(50),
    @Ip       varchar(45),
    @Equipo   varchar(100),
    @Intentos tinyint
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE seg.Usuario SET Bloqueado = 1 WHERE Usuario = @Usuario;
    INSERT INTO log.AccesoBloqueo (Usuario, Ip, Equipo, Intentos) VALUES (@Usuario, @Ip, @Equipo, @Intentos);
END
GO

-- ---------- Usuario administrador de PRUEBA ----------
-- Usuario: ADMIN   Contrasena: Babel2026!   (cambiar en el primer acceso)
IF NOT EXISTS (SELECT 1 FROM seg.Usuario WHERE Usuario = 'ADMIN')
    INSERT INTO seg.Usuario (Usuario, HashContrasena, IdCliente, IdPuesto, IdDepartamento, Activo, Bloqueado, DebeCambiarContrasena)
    VALUES ('ADMIN', 'PBKDF2$SHA256$100000$MoqUT94UOX6eeRwW0Yo+Lg==$cKLWfDMvI74o2HeQC3xBgdf26nfb0gpUmdWwrnFlM/s=',
            1, 1, 3, 1, 0, 0);
GO
PRINT 'Modulo seg listo (seg.Usuario, SPs de login y usuario ADMIN de prueba).';
GO
