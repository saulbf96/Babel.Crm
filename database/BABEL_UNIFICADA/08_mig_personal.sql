/*
  BABEL_UNIFICADA - 08. Migración de personal (empleados, asignación y accesos).

  LEE SOLAMENTE bases locales restauradas. No conecta, no respalda y no escribe
  en 10.80.5.189. Fuentes:

    RHBABEL.dbo.NEEM_EMPLEADO                 586 empleados (todos activos)
    CONFIGURACION_APP.dbo.RECE_CLIENTE_EMPLEADO 586 asignaciones (cartera real)
    CONFIGURACION_APP.dbo.REUM_USUARIO_MULTI_CARTERA 43 accesos_multiples

  Mapeos confirmados contra el .exe (FRM_ALTAEMPLEADOS usa Conversion.Val):
    Sexo legacy  1,2 -> 1 MASCULINO | 3 -> 2 FEMENINO | 4 -> 3 OTRO | 0 -> 3 OTRO
    Turno legacy 1,2,3,4 -> 1,2,3,4 (idénticos) | 0 -> 7 NO ESPECIFICADO
    Puesto legacy -> rh.Puesto (los 5 usados existen y están activos)
    Departamento -> el de la cartera asignada; si la cartera no tiene, 12 ADMINISTRACION
    Cartera: RECE_ID_CARTERA si está entre 1 y 13; si no, se deriva de
             RECE_ID_BASE mediante cart.Cartera.IdBaseLegacy.
             Casos reales: 3 filas con cartera 0/base 22 -> cartera 8;
             2 filas con base 0/cartera 1 -> cartera 1.

  No se migran contraseñas (NEPE_PASSWORD): el CRM usa PBKDF2.
  Re-ejecutable: inserciones protegidas con NOT EXISTS y clave única de legacy.
*/
USE BABEL_UNIFICADA;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET XACT_ABORT ON;
GO

BEGIN TRANSACTION;

-- Turno para los 2 empleados cuyo turno legacy es 0 (catálogo CATR_TURNO lo tiene inactivo).
IF NOT EXISTS (SELECT 1 FROM cat.Turno WHERE IdTurno = 7)
    INSERT INTO cat.Turno (IdTurno, Nombre) VALUES (7, 'NO ESPECIFICADO');

-- Asignación legacy ya resuelta a IdCartera del CRM.
SELECT
    r.RECE_ID_EMPLEADO AS IdEmpleadoLegacy,
    COALESCE(
        CASE WHEN r.RECE_ID_CARTERA BETWEEN 1 AND 13 THEN r.RECE_ID_CARTERA END,
        (SELECT c2.IdCartera FROM cart.Cartera c2 WHERE c2.IdBaseLegacy = r.RECE_ID_BASE)
    ) AS IdCartera,
    r.RECE_ID_GCL_EMPL       AS IdRegistroLegacy,
    r.RECE_ID_SEGMENTO       AS IdSegmento,
    r.RECE_ID_PRODUCTO       AS IdProducto,
    r.RECE_ID_CAMPAÑA        AS IdCampana,
    ISNULL(r.RECE_FECHA_REGISTRO, SYSDATETIME()) AS FechaRegistro,
    ISNULL(r.RECE_ACTIVO, 1) AS Activo
INTO #Asignacion
FROM CONFIGURACION_APP.dbo.RECE_CLIENTE_EMPLEADO r;

DECLARE @IdCarga  int;
DECLARE @Leidas   int;
DECLARE @Ins      int;
DECLARE @Omit     int;
CREATE TABLE #IdCarga (IdCarga int);

-- ---------- 1. Empleados ----------
SET @Leidas = (SELECT COUNT(*) FROM RHBABEL.dbo.NEEM_EMPLEADO WHERE NEEM_ACTIVO = 1);
DELETE FROM #IdCarga;
INSERT INTO #IdCarga
EXEC mig.USP_INICIA_CARGA 'MIG_PERSONAL', 'LOCAL', 'RHBABEL', 'rh.Empleado', 'MIGRACION', @Leidas;
SELECT @IdCarga = IdCarga FROM #IdCarga;

INSERT INTO rh.Empleado
    (IdEmpleadoLegacy, Nombre, Paterno, Materno, IdPuesto, IdDepartamento,
     IdSexo, IdTurno, FechaNacimiento, FechaIngreso, Rfc, Curp, Nss, Email,
     Activo, FechaRegistro)
SELECT
    e.NEEM_ID_EMPLEADO,
    LTRIM(RTRIM(ISNULL(e.NEEM_NOMBRE, ''))),
    LTRIM(RTRIM(ISNULL(e.NEEM_PATERNO, ''))),
    NULLIF(LTRIM(RTRIM(ISNULL(e.NEEM_MATERNO, ''))), ''),
    e.NEEM_ID_PUESTO,
    ISNULL(c.IdDepartamento, 12),
    CASE e.NEEM_SEXO WHEN 1 THEN 1 WHEN 2 THEN 1 WHEN 3 THEN 2 WHEN 4 THEN 3 ELSE 3 END,
    CASE e.NEEM_ID_TURNO WHEN 1 THEN 1 WHEN 2 THEN 2 WHEN 3 THEN 3 WHEN 4 THEN 4 ELSE 7 END,
    e.NEEM_FECHA_NACIMIENTO,
    e.NEEM_FECHA_INGRESO,
    NULLIF(LTRIM(RTRIM(e.NEEM_RFC)), ''),
    NULLIF(LTRIM(RTRIM(e.NEEM_CURP)), ''),
    NULLIF(e.NEEM_NSS, 0),
    NULLIF(LTRIM(RTRIM(e.NEEM_EMAIL)), ''),
    e.NEEM_ACTIVO,
    e.NEEM_FECHA_REGISTRO
FROM RHBABEL.dbo.NEEM_EMPLEADO e
LEFT JOIN #Asignacion a ON a.IdEmpleadoLegacy = e.NEEM_ID_EMPLEADO
LEFT JOIN cart.Cartera c ON c.IdCartera = a.IdCartera
WHERE e.NEEM_ACTIVO = 1
  AND NOT EXISTS (SELECT 1 FROM rh.Empleado m WHERE m.IdEmpleadoLegacy = e.NEEM_ID_EMPLEADO);

SET @Ins = @@ROWCOUNT;
SET @Omit = @Leidas - @Ins;
EXEC mig.USP_FINALIZA_CARGA @IdCarga, @Ins, @Omit, NULL, 'TERMINADA',
     'NEEM_EMPLEADO -> rh.Empleado; IdEmpleadoLegacy conservado; contraseñas excluidas.';

-- ---------- 2. Cartera activa de cada empleado ----------
SET @Leidas = (SELECT COUNT(*) FROM #Asignacion WHERE IdCartera IS NOT NULL AND Activo = 1);
DELETE FROM #IdCarga;
INSERT INTO #IdCarga
EXEC mig.USP_INICIA_CARGA 'MIG_PERSONAL', 'LOCAL', 'CONFIGURACION_APP', 'rh.EmpleadoCartera', 'MIGRACION', @Leidas;
SELECT @IdCarga = IdCarga FROM #IdCarga;

INSERT INTO rh.EmpleadoCartera
    (IdEmpleado, IdCartera, IdDepartamento, IdSegmento, IdProducto, IdCampana,
     Activo, FechaRegistro, IdRegistroLegacy)
SELECT
    m.IdEmpleado, a.IdCartera, ISNULL(c.IdDepartamento, 12),
    a.IdSegmento, a.IdProducto, a.IdCampana, a.Activo, a.FechaRegistro, a.IdRegistroLegacy
FROM #Asignacion a
JOIN rh.Empleado m ON m.IdEmpleadoLegacy = a.IdEmpleadoLegacy
LEFT JOIN cart.Cartera c ON c.IdCartera = a.IdCartera
WHERE a.IdCartera IS NOT NULL
  AND a.Activo = 1
  AND NOT EXISTS (SELECT 1 FROM rh.EmpleadoCartera ec
                  WHERE ec.IdEmpleado = m.IdEmpleado AND ec.Activo = 1);

SET @Ins = @@ROWCOUNT;
SET @Omit = @Leidas - @Ins;
EXEC mig.USP_FINALIZA_CARGA @IdCarga, @Ins, @Omit, NULL, 'TERMINADA',
     'RECE_CLIENTE_EMPLEADO -> rh.EmpleadoCartera (una cartera activa por empleado).';

-- ---------- 3. Acceso a múltiples carteras ----------
SET @Leidas = (SELECT COUNT(*) FROM CONFIGURACION_APP.dbo.REUM_USUARIO_MULTI_CARTERA);
DELETE FROM #IdCarga;
INSERT INTO #IdCarga
EXEC mig.USP_INICIA_CARGA 'MIG_PERSONAL', 'LOCAL', 'CONFIGURACION_APP', 'rh.EmpleadoCarteraAcceso', 'MIGRACION', @Leidas;
SELECT @IdCarga = IdCarga FROM #IdCarga;

INSERT INTO rh.EmpleadoCarteraAcceso (IdEmpleado, IdCartera, Activo, FechaRegistro)
SELECT m.IdEmpleado, c.IdCartera, 1, r.REUM_FECHA_REGISTRO
FROM CONFIGURACION_APP.dbo.REUM_USUARIO_MULTI_CARTERA r
JOIN rh.Empleado m ON m.IdEmpleadoLegacy = r.REUM_ID_EMPLEADO
JOIN cart.Cartera c ON c.IdBaseLegacy = r.REUM_ID_BASE
WHERE NOT EXISTS (SELECT 1 FROM rh.EmpleadoCarteraAcceso x
                  WHERE x.IdEmpleado = m.IdEmpleado AND x.IdCartera = c.IdCartera);

SET @Ins = @@ROWCOUNT;
SET @Omit = @Leidas - @Ins;
EXEC mig.USP_FINALIZA_CARGA @IdCarga, @Ins, @Omit, NULL, 'TERMINADA',
     'REUM_USUARIO_MULTI_CARTERA -> rh.EmpleadoCarteraAcceso (base legacy -> IdCartera).';

COMMIT TRANSACTION;
GO

-- ---------- Verificación inmediata ----------
PRINT '--- Migración de personal: conteos ---';
SELECT 'Empleados' AS Dato, COUNT(*) AS Total FROM rh.Empleado
UNION ALL SELECT 'Con IdEmpleadoLegacy', COUNT(*) FROM rh.Empleado WHERE IdEmpleadoLegacy IS NOT NULL
UNION ALL SELECT 'Cartera activa', COUNT(*) FROM rh.EmpleadoCartera WHERE Activo = 1
UNION ALL SELECT 'Accesos multicartera', COUNT(*) FROM rh.EmpleadoCarteraAcceso;
GO

PRINT '--- Control de carga ---';
SELECT IdCarga, Entidad, FilasLeidas, FilasInsertadas, FilasOmitidas, Estatus
FROM mig.ControlCarga ORDER BY IdCarga;
GO
