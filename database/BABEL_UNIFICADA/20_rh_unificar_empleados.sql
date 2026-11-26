-- =====================================================================
--  Unifica a las personas registradas varias veces como empleado.
--
--  BABEL da de alta OTRA VEZ a la misma persona por cada cartera o
--  reingreso (al 26/11/2026: 40 personas, 87 registros, 47 de más; desde
--  2024 y sigue pasando). En el CRM una persona = un empleado.
--
--  Por cada persona (mismo nombre completo, sin importar mayúsculas ni
--  acentos, registros ACTIVOS y no unificados):
--   1. Sobreviviente = el registro que ya tiene usuario; si ninguno, el que
--      tiene más cuentas; a empate, el de ingreso más antiguo.
--   2. Fecha de ingreso del sobreviviente = la MÁS ANTIGUA del grupo
--      (pendiente de confirmar con RH; la original queda en mig.EmpleadoUnificado).
--   3. Carteras: la activa del sobreviviente se queda; las de los repetidos
--      pasan a ser ACCESOS (rh.EmpleadoCarteraAcceso) para "Cambia cartera".
--   4. Todo lo operativo de los repetidos pasa al sobreviviente:
--      ope.Cuenta, ope.Gestion, ope.AgendaLlamada, ope.Nota, ope.BlocNota,
--      ope.Negociacion, ope.Receso, ope.AgenteOperativo, rh.MovimientoBaja,
--      historial de rh.EmpleadoCartera.
--   5. Los repetidos NO se borran: Activo = 0 + IdEmpleadoUnificado = sobreviviente.
--      La migración debe mapear su IdEmpleadoLegacy a ISNULL(IdEmpleadoUnificado, IdEmpleado).
--
--  NO toca legacy.* ni mig.Stg* (copias crudas de BABEL con sus propios ids).
--  Una sola transacción. Idempotente: se vuelve a correr después de cada
--  migración para unificar lo nuevo.
--  Requiere el script 03 (columna rh.Empleado.IdEmpleadoUnificado).
--
--  Uso: sqlcmd -S localhost -E -I -v SIMULAR=1 -i 20_rh_unificar_empleados.sql   (solo ver)
--       sqlcmd -S localhost -E -I -v SIMULAR=0 -i 20_rh_unificar_empleados.sql   (aplicar)
-- =====================================================================
USE BABEL_UNIFICADA;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID('mig.EmpleadoUnificado') IS NULL
CREATE TABLE mig.EmpleadoUnificado (
    IdEmpleadoDuplicado      int           NOT NULL PRIMARY KEY,
    IdEmpleadoSobreviviente  int           NOT NULL,
    IdEmpleadoLegacy         int           NULL,      -- legacy del registro repetido
    FechaIngresoDuplicado    date          NOT NULL,
    FechaIngresoAnterior     date          NOT NULL,  -- del sobreviviente, antes de unificar
    CarteraDuplicado         tinyint       NULL,
    PuestoDuplicado          tinyint       NOT NULL,
    CuentasMovidas           int           NOT NULL,
    GestionesMovidas         int           NOT NULL,
    FechaUnion               datetime2(0)  NOT NULL CONSTRAINT DF_EmpleadoUnificado_Fecha DEFAULT (SYSDATETIME())
);
GO

-- Obligatorio: -v SIMULAR=1 (solo ver) o -v SIMULAR=0 (aplicar).
DECLARE @Simular bit = $(SIMULAR);

-- ---------- 1. Grupos y sobreviviente ----------
IF OBJECT_ID('tempdb..#g') IS NOT NULL DROP TABLE #g;
SELECT
    e.IdEmpleado,
    e.IdEmpleadoLegacy,
    e.FechaIngreso,
    e.IdPuesto,
    ec.IdCartera,
    -- llave de persona sin mayúsculas ni acentos
    UPPER(LTRIM(RTRIM(e.Nombre)) + '|' + LTRIM(RTRIM(e.Paterno)) + '|' + LTRIM(RTRIM(ISNULL(e.Materno, ''))))
        COLLATE Latin1_General_CI_AI AS Persona,
    CASE WHEN EXISTS (SELECT 1 FROM seg.Usuario u WHERE u.IdEmpleado = e.IdEmpleado) THEN 1 ELSE 0 END AS TieneUsuario,
    (SELECT COUNT(*) FROM ope.Cuenta c WHERE c.IdEmpleado = e.IdEmpleado) AS Cuentas
INTO #g
FROM rh.Empleado e
LEFT JOIN rh.EmpleadoCartera ec ON ec.IdEmpleado = e.IdEmpleado AND ec.Activo = 1
WHERE e.Activo = 1 AND e.IdEmpleadoUnificado IS NULL;

DELETE g FROM #g g
WHERE (SELECT COUNT(*) FROM #g x WHERE x.Persona = g.Persona) = 1;   -- solo personas repetidas

IF OBJECT_ID('tempdb..#m') IS NOT NULL DROP TABLE #m;
SELECT g.*,
       FIRST_VALUE(g.IdEmpleado) OVER (PARTITION BY g.Persona
           ORDER BY g.TieneUsuario DESC, g.Cuentas DESC, g.FechaIngreso, g.IdEmpleado) AS Sobreviviente,
       MIN(g.FechaIngreso) OVER (PARTITION BY g.Persona) AS IngresoMasAntiguo
INTO #m
FROM #g g;

-- Personas con más de un usuario: no se unifican solas (hay que decidir cuál queda).
IF EXISTS (SELECT Persona FROM #m GROUP BY Persona HAVING SUM(TieneUsuario) > 1)
BEGIN
    SELECT 'NO SE UNIFICAN (más de un usuario)' AS Aviso, Persona, IdEmpleado
    FROM #m WHERE Persona IN (SELECT Persona FROM #m GROUP BY Persona HAVING SUM(TieneUsuario) > 1);
    DELETE FROM #m WHERE Persona IN (SELECT Persona FROM #m GROUP BY Persona HAVING SUM(TieneUsuario) > 1);
END

IF OBJECT_ID('tempdb..#d') IS NOT NULL DROP TABLE #d;
SELECT IdEmpleado AS Dup, Sobreviviente AS Sob, IdEmpleadoLegacy, FechaIngreso, IdCartera, IdPuesto, Cuentas,
       (SELECT COUNT(*) FROM ope.Gestion x WHERE x.IdEmpleado = m.IdEmpleado) AS Gestiones
INTO #d
FROM #m m
WHERE IdEmpleado <> Sobreviviente;

SELECT COUNT(DISTINCT Sob) AS Personas, COUNT(*) AS RegistrosAUnificar,
       SUM(Cuentas) AS CuentasAMover, SUM(Gestiones) AS GestionesAMover
FROM #d;

-- Personas con puesto distinto entre sus registros (RH debe revisar cuál queda).
SELECT 'PUESTO DISTINTO (queda el del sobreviviente)' AS Revisar, d.Sob, ps.Nombre AS PuestoQueQueda, pd.Nombre AS PuestoDelRepetido, d.Dup
FROM #d d
JOIN rh.Empleado s ON s.IdEmpleado = d.Sob
JOIN rh.Puesto ps ON ps.IdPuesto = s.IdPuesto
JOIN rh.Puesto pd ON pd.IdPuesto = d.IdPuesto
WHERE s.IdPuesto <> d.IdPuesto;

IF @Simular = 1 OR NOT EXISTS (SELECT 1 FROM #d)
BEGIN
    SELECT CASE WHEN @Simular = 1 THEN 'SIMULACIÓN: no se modificó nada.' ELSE 'No hay registros repetidos por unificar.' END AS Resultado;
    RETURN;
END

BEGIN TRAN;

-- ---------- 2. Rastro ----------
INSERT INTO mig.EmpleadoUnificado
    (IdEmpleadoDuplicado, IdEmpleadoSobreviviente, IdEmpleadoLegacy, FechaIngresoDuplicado,
     FechaIngresoAnterior, CarteraDuplicado, PuestoDuplicado, CuentasMovidas, GestionesMovidas)
SELECT d.Dup, d.Sob, d.IdEmpleadoLegacy, d.FechaIngreso, s.FechaIngreso, d.IdCartera, d.IdPuesto, d.Cuentas, d.Gestiones
FROM #d d JOIN rh.Empleado s ON s.IdEmpleado = d.Sob;

-- ---------- 3. Carteras -> accesos ----------
-- El sobreviviente tiene acceso a su propia cartera activa y a las de sus repetidos.
INSERT INTO rh.EmpleadoCarteraAcceso (IdEmpleado, IdCartera, Activo)
SELECT DISTINCT x.Sob, x.IdCartera, 1
FROM (
    SELECT d.Sob, d.IdCartera FROM #d d WHERE d.IdCartera IS NOT NULL
    UNION
    SELECT d.Sob, ec.IdCartera FROM #d d JOIN rh.EmpleadoCartera ec ON ec.IdEmpleado = d.Sob AND ec.Activo = 1
    UNION
    SELECT d.Sob, a.IdCartera FROM #d d JOIN rh.EmpleadoCarteraAcceso a ON a.IdEmpleado = d.Dup AND a.Activo = 1
) x
WHERE NOT EXISTS (SELECT 1 FROM rh.EmpleadoCarteraAcceso a WHERE a.IdEmpleado = x.Sob AND a.IdCartera = x.IdCartera);

UPDATE a SET Activo = 1
FROM rh.EmpleadoCarteraAcceso a
JOIN #d d ON d.Sob = a.IdEmpleado
WHERE a.Activo = 0
  AND (a.IdCartera = d.IdCartera
       OR EXISTS (SELECT 1 FROM rh.EmpleadoCarteraAcceso x WHERE x.IdEmpleado = d.Dup AND x.IdCartera = a.IdCartera AND x.Activo = 1));

DELETE a FROM rh.EmpleadoCarteraAcceso a JOIN #d d ON d.Dup = a.IdEmpleado;

-- Asignaciones de los repetidos: se cierran y pasan al sobreviviente como historial.
UPDATE ec SET Activo = 0, FechaBaja = SYSDATETIME()
FROM rh.EmpleadoCartera ec JOIN #d d ON d.Dup = ec.IdEmpleado
WHERE ec.Activo = 1;

UPDATE ec SET IdEmpleado = d.Sob
FROM rh.EmpleadoCartera ec JOIN #d d ON d.Dup = ec.IdEmpleado;

-- Si el sobreviviente no tenía cartera activa, toma la de uno de sus repetidos.
INSERT INTO rh.EmpleadoCartera (IdEmpleado, IdCartera, IdDepartamento, Activo)
SELECT s.Sob, c.IdCartera, ISNULL(c.IdDepartamento, 12), 1
FROM (SELECT Sob, MIN(IdCartera) AS IdCartera FROM #d WHERE IdCartera IS NOT NULL GROUP BY Sob) s
JOIN cart.Cartera c ON c.IdCartera = s.IdCartera
WHERE NOT EXISTS (SELECT 1 FROM rh.EmpleadoCartera ec WHERE ec.IdEmpleado = s.Sob AND ec.Activo = 1);

-- ---------- 4. Operativo ----------
UPDATE x SET IdEmpleado = d.Sob FROM ope.Cuenta        x JOIN #d d ON d.Dup = x.IdEmpleado;
UPDATE x SET IdEmpleado = d.Sob FROM ope.Gestion       x JOIN #d d ON d.Dup = x.IdEmpleado;
UPDATE x SET IdEmpleado = d.Sob FROM ope.AgendaLlamada x JOIN #d d ON d.Dup = x.IdEmpleado;
UPDATE x SET IdEmpleado = d.Sob FROM ope.Nota          x JOIN #d d ON d.Dup = x.IdEmpleado;
UPDATE x SET IdEmpleado = d.Sob FROM ope.Negociacion   x JOIN #d d ON d.Dup = x.IdEmpleado;
UPDATE x SET IdEmpleado = d.Sob FROM ope.Receso        x JOIN #d d ON d.Dup = x.IdEmpleado;
UPDATE x SET IdEmpleado = d.Sob FROM rh.MovimientoBaja x JOIN #d d ON d.Dup = x.IdEmpleado;

-- Bloc de notas: uno por empleado y cartera; si el sobreviviente ya tiene en esa cartera, se queda en el repetido.
UPDATE x SET IdEmpleado = d.Sob
FROM ope.BlocNota x JOIN #d d ON d.Dup = x.IdEmpleado
WHERE NOT EXISTS (SELECT 1 FROM ope.BlocNota s WHERE s.IdEmpleado = d.Sob AND s.IdCartera = x.IdCartera);

-- Operativo: un solo registro activo por empleado.
UPDATE x SET Activo = 0, FechaBaja = SYSDATETIME()
FROM ope.AgenteOperativo x JOIN #d d ON d.Dup = x.IdEmpleado
WHERE x.Activo = 1;
UPDATE x SET IdEmpleado = d.Sob FROM ope.AgenteOperativo x JOIN #d d ON d.Dup = x.IdEmpleado;

-- Usuarios de los repetidos (no debería haber): pasan al sobreviviente si él no tiene.
UPDATE u SET IdEmpleado = d.Sob
FROM seg.Usuario u JOIN #d d ON d.Dup = u.IdEmpleado
WHERE NOT EXISTS (SELECT 1 FROM seg.Usuario x WHERE x.IdEmpleado = d.Sob);
UPDATE u SET Activo = 0
FROM seg.Usuario u JOIN #d d ON d.Dup = u.IdEmpleado;

-- ---------- 5. Empleados ----------
UPDATE s SET FechaIngreso = m.IngresoMasAntiguo
FROM rh.Empleado s
JOIN (SELECT DISTINCT Sobreviviente, IngresoMasAntiguo FROM #m) m ON m.Sobreviviente = s.IdEmpleado
WHERE s.FechaIngreso > m.IngresoMasAntiguo;

UPDATE e SET Activo = 0, FechaBaja = SYSDATETIME(), IdEmpleadoUnificado = d.Sob
FROM rh.Empleado e JOIN #d d ON d.Dup = e.IdEmpleado;

INSERT INTO log.Auditoria (Usuario, Accion, Entidad, IdEntidad, Detalle)
SELECT 'SCRIPT_20', 'UNIFICA_EMPLEADO', 'rh.Empleado', CAST(d.Dup AS varchar(20)),
       CONCAT('Registro repetido unificado en empleado ', d.Sob, '; cuentas: ', d.Cuentas, '; gestiones: ', d.Gestiones)
FROM #d d;

COMMIT;

SELECT 'Unificación terminada.' AS Resultado,
       (SELECT COUNT(*) FROM #d) AS RegistrosUnificados,
       (SELECT COUNT(DISTINCT Sob) FROM #d) AS Personas;
GO
