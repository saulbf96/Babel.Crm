/*
  BABEL_UNIFICADA - RECARGA / 03. Verificación posterior a la recarga.
  Solo lectura: conteos, control de cargas y estado de las FKs de ope.
*/
USE BABEL_UNIFICADA;
GO
SET NOCOUNT ON;
GO

PRINT '--- Conteos finales ---';
SELECT 'ope.Cuenta' AS Entidad, COUNT(*) AS Filas FROM ope.Cuenta
UNION ALL SELECT 'ope.Telefono',   COUNT(*) FROM ope.Telefono
UNION ALL SELECT 'ope.Gestion',    COUNT(*) FROM ope.Gestion
UNION ALL SELECT 'ope.Promesa',    COUNT(*) FROM ope.Promesa
UNION ALL SELECT 'ope.Demografico',COUNT(*) FROM ope.Demografico;
GO

PRINT '--- Cuentas por cartera ---';
SELECT c.IdCartera, c.Nombre, COUNT(cu.IdCuenta) AS Cuentas
FROM cart.Cartera c
LEFT JOIN ope.Cuenta cu ON cu.IdCartera = c.IdCartera AND cu.IdControlLegacy > 0
GROUP BY c.IdCartera, c.Nombre
ORDER BY c.IdCartera;
GO

PRINT '--- Estado de mig.ControlCarga ---';
SELECT Estatus, COUNT(*) AS Cargas
FROM mig.ControlCarga
WHERE NombreCarga = 'OPERATIVO_COMPLETO_13_CARTERAS'
GROUP BY Estatus;
GO

PRINT '--- Integridad de FKs con padre en ope ---';
SELECT CASE WHEN COUNT(*) = 0
            THEN 'OK: todas habilitadas y confiables'
            ELSE 'ERROR: hay FKs deshabilitadas o no confiables' END AS Resultado,
       COUNT(*) AS FKsConProblema
FROM sys.foreign_keys fk
WHERE OBJECT_SCHEMA_NAME(fk.referenced_object_id) = N'ope'
  AND (fk.is_disabled = 1 OR fk.is_not_trusted = 1);
GO
