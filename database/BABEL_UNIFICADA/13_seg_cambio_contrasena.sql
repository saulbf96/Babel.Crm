-- =====================================================================
--  Cambio de contraseña del CRM (equivale a FRM_CAMBIOPASS del .exe).
--  Guarda el hash PBKDF2 (ya cifrado por el backend) y baja la bandera
--  DebeCambiarContrasena para que el login deje de exigir el cambio.
-- =====================================================================
USE BABEL_UNIFICADA;
-- Obligatorio: rh.Empleado y otras tablas tienen índices filtrados (error 1934 si se crean los SP con OFF).
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE seg.USP_CAMBIAR_CONTRASENA
    @IdUsuario      int,
    @HashContrasena varchar(200)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE seg.Usuario
       SET HashContrasena        = @HashContrasena,
           DebeCambiarContrasena = 0
     WHERE IdUsuario = @IdUsuario;
END
GO
