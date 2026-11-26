SET NOCOUNT ON;
PRINT '== Verificación migración total ==';

SELECT 'legacy_tablas' AS Tipo, COUNT(*) AS Valor
FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id WHERE s.name='legacy';

SELECT TOP 30 s.name+'.'+t.name AS Tabla, SUM(p.rows) AS Filas
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id=t.schema_id
JOIN sys.partitions p ON p.object_id=t.object_id AND p.index_id IN (0,1)
WHERE s.name='legacy'
GROUP BY s.name+'.'+t.name
ORDER BY Filas DESC;

PRINT '== Conteos ope.* ==';
SELECT 'ope.Cuenta' Entidad, COUNT(*) Filas FROM ope.Cuenta
UNION ALL SELECT 'ope.Telefono', COUNT(*) FROM ope.Telefono
UNION ALL SELECT 'ope.Gestion', COUNT(*) FROM ope.Gestion
UNION ALL SELECT 'ope.Promesa', COUNT(*) FROM ope.Promesa
UNION ALL SELECT 'ope.Demografico', COUNT(*) FROM ope.Demografico
UNION ALL SELECT 'ope.MoraFuenteIngreso', COUNT(*) FROM ope.MoraFuenteIngreso
UNION ALL SELECT 'ope.EvolucionCuenta', COUNT(*) FROM ope.EvolucionCuenta
UNION ALL SELECT 'ope.DatoCuenta', COUNT(*) FROM ope.DatoCuenta
UNION ALL SELECT 'ope.Nota', COUNT(*) FROM ope.Nota
UNION ALL SELECT 'ope.Negociacion', COUNT(*) FROM ope.Negociacion
UNION ALL SELECT 'ope.AgendaLlamada', COUNT(*) FROM ope.AgendaLlamada
UNION ALL SELECT 'ope.BlocNota', COUNT(*) FROM ope.BlocNota
UNION ALL SELECT 'ope.Receso', COUNT(*) FROM ope.Receso;

PRINT '== Huérfanos básicos ==';
SELECT 'Telefono sin cuenta' Caso, COUNT(*) Filas FROM ope.Telefono t LEFT JOIN ope.Cuenta c ON c.IdCuenta=t.IdCuenta WHERE c.IdCuenta IS NULL
UNION ALL SELECT 'Gestion sin cuenta', COUNT(*) FROM ope.Gestion g LEFT JOIN ope.Cuenta c ON c.IdCuenta=g.IdCuenta WHERE c.IdCuenta IS NULL
UNION ALL SELECT 'Promesa sin cuenta', COUNT(*) FROM ope.Promesa p LEFT JOIN ope.Cuenta c ON c.IdCuenta=p.IdCuenta WHERE c.IdCuenta IS NULL
UNION ALL SELECT 'Demografico sin cuenta', COUNT(*) FROM ope.Demografico d LEFT JOIN ope.Cuenta c ON c.IdCuenta=d.IdCuenta WHERE c.IdCuenta IS NULL;

PRINT '== Errores de migración (si existen) ==';
IF OBJECT_ID('tempdb..#e') IS NOT NULL DROP TABLE #e;
-- errores_migracion.log es archivo externo; revisar manualmente si existe.
SELECT 'Revisar errores_migracion.log en MIGRACION_TOTAL si existe' AS Nota;
