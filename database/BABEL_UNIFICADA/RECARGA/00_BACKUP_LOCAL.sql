/*
  BABEL_UNIFICADA - RECARGA / 00. Backup LOCAL previo (OPCIONAL).

  Se ejecuta en localhost, NUNCA en 10.80.5.189.
  Si SERVERPROPERTY('InstanceDefaultBackupPath') no devuelve una ruta, se usa
  C:\ por defecto; si el servicio de SQL Server no puede escribir ahí, cambia
  la ruta en @rutaBase por una carpeta con permisos para el servicio.
*/
USE master;
GO

DECLARE @rutaBase nvarchar(4000) = CONVERT(nvarchar(4000), SERVERPROPERTY('InstanceDefaultBackupPath'));
IF @rutaBase IS NULL OR LTRIM(RTRIM(@rutaBase)) = N'' SET @rutaBase = N'C:\';
IF RIGHT(@rutaBase, 1) <> N'\' SET @rutaBase = @rutaBase + N'\';

DECLARE @ruta nvarchar(4000) = @rutaBase
    + N'BABEL_UNIFICADA_antes_recarga_'
    + CONVERT(nvarchar(8), GETDATE(), 112) + N'_'
    + REPLACE(CONVERT(nvarchar(8), GETDATE(), 108), N':', N'')
    + N'.bak';

DECLARE @sql nvarchar(max) = N'BACKUP DATABASE [BABEL_UNIFICADA] TO DISK = @ruta WITH COMPRESSION, INIT, STATS = 10;';
EXEC sp_executesql @sql, N'@ruta nvarchar(4000)', @ruta = @ruta;
PRINT 'Backup local creado en: ' + @ruta;
GO
