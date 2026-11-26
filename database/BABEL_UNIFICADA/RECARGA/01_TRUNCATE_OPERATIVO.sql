/*
  BABEL_UNIFICADA - RECARGA / 01. TRUNCATE de datos operativos y staging.

  Borra TODAS las tablas de ope.* (incluidas Nota, BlocNota, Receso,
  AgendaLlamada, Negociacion, DatoCuenta, EvolucionCuenta y MoraFuenteIngreso),
  las tablas mig.Stg* y el historial mig.ControlCarga.

  NO toca seg, rh, cart, cat, adm ni log: usuarios (incluido GESTOR),
  contraseñas, empleados, carteras, asignaciones y catálogos se conservan.

  TRUNCATE no se permite mientras otra tabla referencie a la tabla con una FK,
  así que se deshabilitan solo las FKs cuyo padre está en ope, se trunca y se
  vuelven a habilitar con validación (WITH CHECK). Todo queda vacío, así que la
  validación siempre pasa.

  Después de este script, ejecutar 11_mig_operativo_completo.ps1.
*/
USE BABEL_UNIFICADA;
GO
SET NOCOUNT ON;
GO

PRINT '--- Deshabilitando FKs con tabla padre en ope ---';
GO
DECLARE @sql nvarchar(max) = N'';
SELECT @sql = @sql
     + N'ALTER TABLE ' + QUOTENAME(OBJECT_SCHEMA_NAME(fk.parent_object_id)) + N'.' + QUOTENAME(OBJECT_NAME(fk.parent_object_id))
     + N' NOCHECK CONSTRAINT ' + QUOTENAME(fk.name) + N';' + CHAR(13)
FROM sys.foreign_keys fk
WHERE OBJECT_SCHEMA_NAME(fk.referenced_object_id) = N'ope'
  AND fk.is_disabled = 0;
IF LEN(@sql) > 0 EXEC sp_executesql @sql;
GO

PRINT '--- TRUNCATE de ope.* y mig.Stg* ---';
GO
DECLARE @tablas TABLE (Nombre nvarchar(400) NOT NULL PRIMARY KEY);

INSERT INTO @tablas (Nombre)
SELECT QUOTENAME(OBJECT_SCHEMA_NAME(object_id)) + N'.' + QUOTENAME(name)
FROM sys.tables
WHERE schema_id = SCHEMA_ID(N'ope');

INSERT INTO @tablas (Nombre)
SELECT QUOTENAME(TABLE_SCHEMA) + N'.' + QUOTENAME(TABLE_NAME)
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = N'mig' AND TABLE_NAME LIKE N'Stg%';

DECLARE @nombre nvarchar(400);
DECLARE @sentencia nvarchar(max);
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT Nombre FROM @tablas ORDER BY Nombre;
OPEN cur;
FETCH NEXT FROM cur INTO @nombre;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sentencia = N'TRUNCATE TABLE ' + @nombre + N';';
    EXEC sp_executesql @sentencia;
    PRINT @sentencia;
    FETCH NEXT FROM cur INTO @nombre;
END
CLOSE cur;
DEALLOCATE cur;
GO

PRINT '--- TRUNCATE de mig.ControlCarga ---';
GO
IF OBJECT_ID(N'mig.ControlCarga', N'U') IS NOT NULL
BEGIN
    TRUNCATE TABLE mig.ControlCarga;
    PRINT 'TRUNCATE TABLE mig.ControlCarga;';
END
GO

PRINT '--- Re-habilitando y validando FKs ---';
GO
DECLARE @sql nvarchar(max) = N'';
SELECT @sql = @sql
     + N'ALTER TABLE ' + QUOTENAME(OBJECT_SCHEMA_NAME(fk.parent_object_id)) + N'.' + QUOTENAME(OBJECT_NAME(fk.parent_object_id))
     + N' WITH CHECK CHECK CONSTRAINT ' + QUOTENAME(fk.name) + N';' + CHAR(13)
FROM sys.foreign_keys fk
WHERE OBJECT_SCHEMA_NAME(fk.referenced_object_id) = N'ope'
  AND fk.is_disabled = 1;
IF LEN(@sql) > 0 EXEC sp_executesql @sql;
GO

IF EXISTS (
    SELECT 1 FROM sys.foreign_keys fk
    WHERE OBJECT_SCHEMA_NAME(fk.referenced_object_id) = N'ope'
      AND (fk.is_disabled = 1 OR fk.is_not_trusted = 1)
)
BEGIN
    RAISERROR('Quedaron FKs deshabilitadas o no confiables en ope. Revisa antes de migrar.', 16, 1);
END
ELSE
BEGIN
    PRINT 'TRUNCATE terminado. FKs de ope habilitadas y confiables.';
END
GO
