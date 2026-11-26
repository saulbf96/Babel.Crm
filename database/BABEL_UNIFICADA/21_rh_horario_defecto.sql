-- =====================================================================
--  Horario por defecto para empleados activos que no tienen horario.
--
--  Regla del usuario (26/11/2026): el horario por defecto es 08:00 a 14:30
--  (como la contraseña temporal); el admin lo ajusta en Consulta de
--  empleados > Editar, o marca "No aplica horario".
--  Los empleados migrados de BABEL solo traen turno (matutino/vespertino),
--  sin horas: aquí reciben el horario por defecto.
--
--  OJO: a los VESPERTINOS el 08:00-14:30 no les corresponde; el script los
--  lista al final para que el admin los ajuste (o se ajusta @SalidaVespertino).
--
--  Idempotente: solo toca empleados ACTIVOS con AplicaHorario = 1 y SIN horas.
--  Correr después de cada migración (después del 20 y antes del 18).
--  Uso: sqlcmd -S localhost -E -I -i 21_rh_horario_defecto.sql
-- =====================================================================
USE BABEL_UNIFICADA;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;
GO

DECLARE @Entrada time(0) = '08:00', @Salida time(0) = '14:30';

UPDATE rh.Empleado
   SET HoraEntrada = @Entrada, HoraSalida = @Salida
 WHERE Activo = 1 AND AplicaHorario = 1
   AND HoraEntrada IS NULL AND HoraSalida IS NULL;

SELECT @@ROWCOUNT AS EmpleadosConHorarioPorDefecto;

-- Vespertinos de BABEL que quedaron con el horario por defecto: revisar.
SELECT e.IdEmpleado, LTRIM(RTRIM(CONCAT(e.Nombre, ' ', e.Paterno, ' ', ISNULL(e.Materno, '')))) AS Empleado,
       t.Nombre AS TurnoBabel, CONVERT(varchar(5), e.HoraEntrada) AS Entrada, CONVERT(varchar(5), e.HoraSalida) AS Salida
FROM rh.Empleado e
JOIN cat.Turno t ON t.IdTurno = e.IdTurno
WHERE e.Activo = 1 AND e.AplicaHorario = 1 AND e.IdTurno IN (2, 4)   -- vespertino, nocturno
  AND e.HoraEntrada = @Entrada AND e.HoraSalida = @Salida
ORDER BY e.Paterno, e.Nombre;
GO
