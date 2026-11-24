/*
  BABEL_CRM - 02. Modulo RH: catalogos + empleados + SP de consulta + datos de ejemplo FICTICIOS.
  Equivale a la pantalla "Consulta Empleados" de BABEL (FRM_CONSULTAEMPLEADOS).
  Origen del diseno: RHBABEL.dbo.NEEM_EMPLEADO (solo estructura; los datos aqui son inventados).
  Ejecutar despues de 01_crear_base.sql.
*/
USE BABEL_CRM;
GO

-- ---------- Catalogos ----------
IF OBJECT_ID('rh.Puesto') IS NULL
CREATE TABLE rh.Puesto (
    IdPuesto  tinyint       NOT NULL PRIMARY KEY,
    Nombre    nvarchar(60)  NOT NULL
);
GO
IF OBJECT_ID('rh.Departamento') IS NULL
CREATE TABLE rh.Departamento (
    IdDepartamento tinyint      NOT NULL PRIMARY KEY,
    Nombre         nvarchar(60) NOT NULL
);
GO

-- ---------- Empleados ----------
-- Solo campos NO sensibles. En BABEL, domicilio/sueldo/telefonos van cifrados (varbinary);
-- aqui no se incluyen para esta pantalla de consulta.
IF OBJECT_ID('rh.Empleado') IS NULL
CREATE TABLE rh.Empleado (
    IdEmpleado      int           NOT NULL PRIMARY KEY,
    IdCliente       int           NOT NULL,
    Nombre          nvarchar(50)  NOT NULL,
    Paterno         nvarchar(50)  NOT NULL,
    Materno         nvarchar(50)  NULL,
    IdPuesto        tinyint       NOT NULL,
    IdDepartamento  tinyint       NOT NULL,
    Rfc             varchar(13)   NULL,
    Email           varchar(150)  NULL,
    FechaIngreso    date          NOT NULL,
    Activo          bit           NOT NULL CONSTRAINT DF_Empleado_Activo DEFAULT(1)
);
GO

-- ---------- SP de consulta (parametrizado, equivalente a CONSULTA_NEEM_EMPLEADO_FULL) ----------
CREATE OR ALTER PROCEDURE rh.USP_CONSULTA_EMPLEADOS
    @IdCliente    int          = NULL,  -- NULL = todos los clientes que el usuario pueda ver
    @Nombre       nvarchar(100)= NULL,  -- busca en nombre/paterno/materno
    @IdPuesto     tinyint      = NULL,
    @SoloActivos  bit          = 1
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        e.IdEmpleado,
        e.IdCliente,
        cli.Nombre AS Cliente,
        LTRIM(RTRIM(e.Nombre + ' ' + e.Paterno + ' ' + ISNULL(e.Materno, ''))) AS NombreCompleto,
        e.IdPuesto,
        pu.Nombre  AS Puesto,
        e.IdDepartamento,
        de.Nombre  AS Departamento,
        e.Rfc,
        e.Email,
        e.FechaIngreso,
        e.Activo
    FROM rh.Empleado e
    JOIN seg.Cliente     cli ON cli.IdCliente = e.IdCliente
    JOIN rh.Puesto        pu ON pu.IdPuesto = e.IdPuesto
    JOIN rh.Departamento  de ON de.IdDepartamento = e.IdDepartamento
    WHERE (@IdCliente   IS NULL OR e.IdCliente = @IdCliente)
      AND (@IdPuesto    IS NULL OR e.IdPuesto  = @IdPuesto)
      AND (@SoloActivos = 0      OR e.Activo   = 1)
      AND (@Nombre IS NULL OR @Nombre = ''
           OR e.Nombre  LIKE '%' + @Nombre + '%'
           OR e.Paterno LIKE '%' + @Nombre + '%'
           OR e.Materno LIKE '%' + @Nombre + '%')
    ORDER BY e.Paterno, e.Materno, e.Nombre;
END
GO

-- ---------- Datos de ejemplo FICTICIOS ----------
IF NOT EXISTS (SELECT 1 FROM seg.Cliente)
    INSERT INTO seg.Cliente (IdCliente, Nombre) VALUES
        (1, N'Cliente Demo'), (2, N'Financiera Ejemplo');
GO
IF NOT EXISTS (SELECT 1 FROM rh.Puesto)
    INSERT INTO rh.Puesto (IdPuesto, Nombre) VALUES
        (1, N'Director General'), (5, N'Gerente de Operacion'), (8, N'Administrativo'),
        (14, N'Ejecutivo Telefonico'), (16, N'Coordinador de Cartera'), (17, N'Supervisor de Cartera');
GO
IF NOT EXISTS (SELECT 1 FROM rh.Departamento)
    INSERT INTO rh.Departamento (IdDepartamento, Nombre) VALUES
        (1, N'Operaciones'), (2, N'Cobranza'), (3, N'Administracion'), (4, N'Recursos Humanos');
GO
IF NOT EXISTS (SELECT 1 FROM rh.Empleado)
    INSERT INTO rh.Empleado (IdEmpleado, IdCliente, Nombre, Paterno, Materno, IdPuesto, IdDepartamento, Rfc, Email, FechaIngreso, Activo) VALUES
        (1001, 1, N'Ana',     N'Garcia',   N'Lopez',    16, 2, 'GALA850101AB1', 'ana.garcia@ejemplo.mx',    '2021-03-15', 1),
        (1002, 1, N'Luis',    N'Martinez', N'Ramirez',  14, 1, 'MARL900202CD2', 'luis.martinez@ejemplo.mx', '2022-07-01', 1),
        (1003, 1, N'Maria',   N'Hernandez',N'Soto',     17, 2, 'HESM880303EF3', 'maria.hernandez@ejemplo.mx','2020-11-20', 1),
        (1004, 2, N'Carlos',  N'Diaz',     N'Flores',    8, 3, 'DIFC950404GH4', 'carlos.diaz@ejemplo.mx',   '2023-01-10', 1),
        (1005, 2, N'Sofia',   N'Reyes',    NULL,         5, 1, 'RESO870505IJ5', 'sofia.reyes@ejemplo.mx',   '2019-05-30', 1),
        (1006, 1, N'Jorge',   N'Nunez',    N'Castro',   14, 2, 'NUCJ910606KL6', 'jorge.nunez@ejemplo.mx',   '2022-09-12', 0),
        (1007, 2, N'Elena',   N'Vargas',   N'Mora',      1, 3, 'VAME800707MN7', 'elena.vargas@ejemplo.mx',  '2018-02-01', 1);
GO
PRINT 'Modulo RH listo (catalogos, empleados de ejemplo y SP rh.USP_CONSULTA_EMPLEADOS).';
GO
