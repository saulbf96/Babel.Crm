/*
  BABEL_UNIFICADA - 04. Seguridad: usuarios del CRM, login y bloqueo por intentos.

  El .exe viejo valida contra CONFIGURACION_APP.DBO.CONSULTA_NEEM_EMPLEADO y
  devuelve la contrasena en claro. Eso NO se migra. El CRM administra sus
  propias credenciales con PBKDF2 (nunca se guarda la contrasena en claro).

  Usuario de prueba: ADMIN / Babel2026!
  (DebeCambiarContrasena = 0 para pruebas; se puede activar despues).
*/
USE BABEL_UNIFICADA;
GO

IF OBJECT_ID('log.AccesoBloqueo') IS NULL
CREATE TABLE log.AccesoBloqueo (
    IdBloqueo bigint       NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Usuario   varchar(50)  NOT NULL,
    Ip        varchar(45)  NULL,
    Equipo    varchar(100) NULL,
    Intentos  tinyint      NOT NULL,
    Fecha     datetime2(0) NOT NULL CONSTRAINT DF_AccesoBloqueo_Fecha DEFAULT (SYSDATETIME())
);
GO

IF OBJECT_ID('seg.Usuario') IS NULL
CREATE TABLE seg.Usuario (
    IdUsuario              int           NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Usuario                varchar(50)   NOT NULL,
    HashContrasena         varchar(200)  NOT NULL,   -- PBKDF2$SHA256$iter$salt$key
    IdEmpleado             int           NULL,        -- enlace opcional a rh.Empleado
    IdPuesto               tinyint       NOT NULL,    -- define el perfil (appsettings Seguridad:PuestosPorPerfil)
    IdDepartamento         tinyint       NOT NULL,
    Activo                 bit           NOT NULL CONSTRAINT DF_Usuario_Activo DEFAULT (1),
    Bloqueado              bit           NOT NULL CONSTRAINT DF_Usuario_Bloqueado DEFAULT (0),
    DebeCambiarContrasena  bit           NOT NULL CONSTRAINT DF_Usuario_DebeCambiar DEFAULT (0),
    FechaRegistro          datetime2(0)  NOT NULL CONSTRAINT DF_Usuario_Fecha DEFAULT (SYSDATETIME()),
    UltimoAcceso           datetime2(0)  NULL,
    CONSTRAINT UQ_Usuario_Usuario UNIQUE (Usuario),
    CONSTRAINT FK_Usuario_Empleado     FOREIGN KEY (IdEmpleado)     REFERENCES rh.Empleado (IdEmpleado),
    CONSTRAINT FK_Usuario_Puesto       FOREIGN KEY (IdPuesto)       REFERENCES rh.Puesto (IdPuesto),
    CONSTRAINT FK_Usuario_Departamento FOREIGN KEY (IdDepartamento) REFERENCES rh.Departamento (IdDepartamento)
);
GO

-- =====================================================================
--  Login: valida el hash en el backend y devuelve la cartera inicial.
--  La cartera inicial es la primera asignacion activa del empleado; si el
--  usuario no tiene empleado (ADMIN de arranque), se usa la primera cartera.
-- =====================================================================
CREATE OR ALTER PROCEDURE seg.USP_CONSULTA_USUARIO
    @Usuario varchar(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1
        u.IdUsuario,
        u.Usuario,
        u.HashContrasena,
        ISNULL(u.IdEmpleado, 0) AS IdEmpleado,
        u.IdPuesto,
        u.IdDepartamento,
        u.Activo,
        u.Bloqueado,
        ISNULL(ca.IdCartera, 0) AS IdCartera,
        ISNULL(ca.Nombre, '') AS Cartera
    FROM seg.Usuario u
    OUTER APPLY (
        SELECT TOP 1 x.IdCartera
        FROM rh.EmpleadoCartera x
        WHERE x.IdEmpleado = u.IdEmpleado AND x.Activo = 1
        ORDER BY x.IdEmpleadoCartera DESC
    ) ec
    OUTER APPLY (
        -- Cartera activa del empleado. Si el usuario no tiene empleado (ADMIN de
        -- arranque), se toma la primera cartera activa como cartera inicial.
        SELECT TOP 1 c0.IdCartera, c0.Nombre
        FROM cart.Cartera c0
        WHERE c0.Activo = 1
        ORDER BY CASE WHEN c0.IdCartera = ec.IdCartera THEN 0 ELSE 1 END, c0.IdCartera
    ) ca
    WHERE u.Usuario = @Usuario;
END
GO

CREATE OR ALTER PROCEDURE seg.USP_DEBE_CAMBIAR
    @IdEmpleado int
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 1 AS DebeCambiar
    FROM seg.Usuario
    WHERE IdEmpleado = @IdEmpleado
      AND DebeCambiarContrasena = 1
      AND Activo = 1;
END
GO

CREATE OR ALTER PROCEDURE seg.USP_BLOQUEAR_USUARIO
    @Usuario  varchar(50),
    @Ip       varchar(45)  = NULL,
    @Equipo   varchar(100) = NULL,
    @Intentos tinyint
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO log.AccesoBloqueo (Usuario, Ip, Equipo, Intentos)
    VALUES (@Usuario, @Ip, @Equipo, @Intentos);

    -- Misma regla del .exe: 5 intentos fallidos en 15 minutos bloquean la cuenta.
    IF (SELECT COUNT(*) FROM log.AccesoBloqueo
        WHERE Usuario = @Usuario AND Fecha >= DATEADD(MINUTE, -15, SYSDATETIME())) >= 5
        UPDATE seg.Usuario SET Bloqueado = 1 WHERE Usuario = @Usuario;
END
GO

CREATE OR ALTER PROCEDURE seg.USP_REGISTRA_ACCESO
    @IdUsuario int
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE seg.Usuario SET UltimoAcceso = SYSDATETIME() WHERE IdUsuario = @IdUsuario;
END
GO

-- =====================================================================
--  Usuario ADMIN de arranque
--  Contrasena: Babel2026!  (hash PBKDF2-SHA256, 100000 iteraciones)
-- =====================================================================
IF NOT EXISTS (SELECT 1 FROM seg.Usuario WHERE Usuario = 'ADMIN')
    INSERT INTO seg.Usuario
        (Usuario, HashContrasena, IdEmpleado, IdPuesto, IdDepartamento, Activo, Bloqueado, DebeCambiarContrasena)
    VALUES
        ('ADMIN',
         'PBKDF2$SHA256$100000$MoqUT94UOX6eeRwW0Yo+Lg==$cKLWfDMvI74o2HeQC3xBgdf26nfb0gpUmdWwrnFlM/s=',
         NULL, 1, 12, 1, 0, 0);
GO

PRINT 'Modulo seg listo (seg.Usuario, login, bloqueo y usuario ADMIN de prueba).';
GO
