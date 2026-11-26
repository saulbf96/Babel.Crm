-- =====================================================================
--  Historial de altas de empleados (pantalla Alta de empleados).
--
--  Fuente: la bitácora (log.Auditoria, Accion = 'ALTA_EMPLEADO'), NO la
--  fecha de registro del empleado: así solo aparecen las altas hechas en
--  el sistema y no los ~590 empleados que llegaron por migración.
--  Alcance: altas en la cartera de la sesión. Rango de fechas inclusivo.
--  Idempotente.
-- =====================================================================
USE BABEL_UNIFICADA;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Auditoria_Accion_Fecha' AND object_id = OBJECT_ID('log.Auditoria'))
    CREATE INDEX IX_Auditoria_Accion_Fecha ON log.Auditoria (Accion, Fecha) INCLUDE (Usuario, Entidad, IdEntidad);
GO

CREATE OR ALTER PROCEDURE rh.USP_CONSULTA_ALTAS
    @IdCartera tinyint,
    @Desde     date,
    @Hasta     date
AS
BEGIN
    SET NOCOUNT ON;

    IF @Desde IS NULL OR @Hasta IS NULL OR @Desde > @Hasta
        THROW 50040, 'Revisa el rango de fechas: "Desde" no puede ser mayor que "Hasta".', 1;
    IF @Hasta > CAST(SYSDATETIME() AS date)
        THROW 50042, 'No se pueden consultar fechas futuras: "Hasta" debe ser hoy o un día anterior.', 1;
    IF DATEDIFF(DAY, @Desde, @Hasta) > 366
        THROW 50041, 'El rango no puede ser mayor a un año.', 1;

    SELECT
        a.Fecha AS FechaAlta,
        a.Usuario AS RegistradoPor,
        LTRIM(RTRIM(CONCAT(e.Nombre, ' ', e.Paterno, ' ', ISNULL(e.Materno, '')))) AS NombreCompleto,
        u.Usuario,
        p.Nombre AS Puesto,
        e.HoraEntrada,
        e.HoraSalida,
        e.AplicaHorario,
        e.Activo
    FROM log.Auditoria a
    JOIN rh.Empleado e ON e.IdEmpleado = TRY_CAST(a.IdEntidad AS int)
    JOIN rh.Puesto p ON p.IdPuesto = e.IdPuesto
    OUTER APPLY (SELECT TOP 1 su.Usuario FROM seg.Usuario su WHERE su.IdEmpleado = e.IdEmpleado ORDER BY su.Activo DESC, su.IdUsuario) u
    WHERE a.Accion = 'ALTA_EMPLEADO'
      AND a.Entidad = 'rh.Empleado'
      AND a.Fecha >= @Desde
      AND a.Fecha < DATEADD(DAY, 1, @Hasta)
      AND (EXISTS (SELECT 1 FROM rh.EmpleadoCartera ec WHERE ec.IdEmpleado = e.IdEmpleado AND ec.IdCartera = @IdCartera)
           OR EXISTS (SELECT 1 FROM rh.EmpleadoCarteraAcceso ac WHERE ac.IdEmpleado = e.IdEmpleado AND ac.IdCartera = @IdCartera))
    ORDER BY a.Fecha DESC;
END
GO
