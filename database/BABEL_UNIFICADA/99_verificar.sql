/*
  BABEL_UNIFICADA - 99. Verificacion rapida despues de ejecutar 01..06.
  No modifica datos: solo cuenta y muestra catalogos/SPs.
*/
USE BABEL_UNIFICADA;
GO

SET NOCOUNT ON;

SELECT 'Puestos'       AS Dato, COUNT(*) AS Total FROM rh.Puesto
UNION ALL SELECT 'Departamentos', COUNT(*) FROM rh.Departamento
UNION ALL SELECT 'Sexos',         COUNT(*) FROM cat.Sexo
UNION ALL SELECT 'Turnos',        COUNT(*) FROM cat.Turno
UNION ALL SELECT 'Clientes',      COUNT(*) FROM cart.Cliente
UNION ALL SELECT 'Carteras',      COUNT(*) FROM cart.Cartera
UNION ALL SELECT 'Empleados',     COUNT(*) FROM rh.Empleado
UNION ALL SELECT 'Asignaciones',  COUNT(*) FROM rh.EmpleadoCartera
UNION ALL SELECT 'Operativo',     COUNT(*) FROM ope.AgenteOperativo
UNION ALL SELECT 'Procesos',      COUNT(*) FROM adm.ProcesoAsignacion
UNION ALL SELECT 'Usuarios',      COUNT(*) FROM seg.Usuario
UNION ALL SELECT 'Cargas',        COUNT(*) FROM adm.CargaAsignacion;
GO

PRINT '--- Carteras (IdCartera / IdBaseLegacy / Nombre / Departamento) ---';
SELECT c.IdCartera, c.IdBaseLegacy, c.Nombre, d.Nombre AS Departamento, c.Activo
FROM cart.Cartera c
LEFT JOIN rh.Departamento d ON d.IdDepartamento = c.IdDepartamento
ORDER BY c.IdCartera;
GO

PRINT '--- Usuario ADMIN ---';
SELECT IdUsuario, Usuario, IdPuesto, IdDepartamento, Activo, Bloqueado, DebeCambiarContrasena
FROM seg.Usuario;
GO

PRINT '--- SPs creados ---';
SELECT s.name AS Esquema, o.name AS Procedimiento
FROM sys.procedures o
INNER JOIN sys.schemas s ON s.schema_id = o.schema_id
ORDER BY s.name, o.name;
GO

PRINT '--- Prueba de login (debe devolver ADMIN y cartera 1) ---';
EXEC seg.USP_CONSULTA_USUARIO @Usuario = 'ADMIN';
GO

PRINT '--- Prueba de carteras del ADMIN (debe devolver 13) ---';
EXEC cart.USP_CONSULTA_CARTERAS @IdUsuario = 1;
GO

PRINT '--- Prueba de consulta de empleados (vacia al inicio) ---';
EXEC rh.USP_CONSULTA_EMPLEADOS;
GO

PRINT 'Verificacion terminada.';
GO
