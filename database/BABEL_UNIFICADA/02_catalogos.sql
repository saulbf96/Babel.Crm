/*
  BABEL_UNIFICADA - 02. Catalogos maestros y carteras.

  Estos datos NO son operativos: son la configuracion minima que necesita la
  aplicacion para funcionar (puestos, departamentos, sexo, turno, clientes y
  carteras). Se tomaron de las bases restauradas para conservar los mismos IDs
  que usa el .exe y facilitar la migracion posterior.

  Mapeo de carteras (legacy):
    IdCartera 1..13  = CART_CARTERA.CART_ID_CARTERA 1..13
    IdBaseLegacy     = CABD_BASES_DATOS.CABD_ID_BASE 15..27
    IdDepartamento   = CADP_DEPARTAMENTO operativo de la cartera (si existe)

  Nota sobre sexo: el .exe viejo solo etiquetaba 1=Masculino y 2=Femenino;
  los registros nuevos usaban 3 y 4 y salian en blanco. En la base nueva el
  catalogo limpio es 1=Masculino, 2=Femenino, 3=Otro. La migracion mapeara
  3->2 y 4->3 para no dejar el dato vacio.
*/
USE BABEL_UNIFICADA;
GO

-- ---------- Puestos (RHBABEL.CAPU_PUESTO) ----------
IF OBJECT_ID('rh.Puesto') IS NULL
CREATE TABLE rh.Puesto (
    IdPuesto   tinyint      NOT NULL PRIMARY KEY,
    Nombre     varchar(50)  NOT NULL,
    Tipo       char(2)      NOT NULL CONSTRAINT DF_Puesto_Tipo DEFAULT (''),
    Gerarquia  tinyint      NOT NULL CONSTRAINT DF_Puesto_Gerarquia DEFAULT (0),
    Activo     bit          NOT NULL CONSTRAINT DF_Puesto_Activo DEFAULT (1)
);
GO

-- ---------- Departamentos (RHBABEL.CADP_DEPARTAMENTO) ----------
IF OBJECT_ID('rh.Departamento') IS NULL
CREATE TABLE rh.Departamento (
    IdDepartamento tinyint     NOT NULL PRIMARY KEY,
    Nombre         varchar(50) NOT NULL,
    Tipo           char(1)     NOT NULL CONSTRAINT DF_Departamento_Tipo DEFAULT ('S'),
    Activo         bit         NOT NULL CONSTRAINT DF_Departamento_Activo DEFAULT (1)
);
GO

-- ---------- Catalogos generales ----------
IF OBJECT_ID('cat.Sexo') IS NULL
CREATE TABLE cat.Sexo (
    IdSexo tinyint     NOT NULL PRIMARY KEY,
    Nombre varchar(30) NOT NULL
);
GO

IF OBJECT_ID('cat.Turno') IS NULL
CREATE TABLE cat.Turno (
    IdTurno tinyint     NOT NULL PRIMARY KEY,
    Nombre  varchar(30) NOT NULL
);
GO

-- ---------- Clientes y carteras ----------
IF OBJECT_ID('cart.Cliente') IS NULL
CREATE TABLE cart.Cliente (
    IdCliente tinyint     NOT NULL PRIMARY KEY,
    Nombre    varchar(75) NOT NULL,
    Activo    bit         NOT NULL CONSTRAINT DF_Cliente_Activo DEFAULT (1)
);
GO

IF OBJECT_ID('cart.Cartera') IS NULL
CREATE TABLE cart.Cartera (
    IdCartera      tinyint     NOT NULL PRIMARY KEY,
    IdCliente      tinyint     NOT NULL,
    Nombre         varchar(75) NOT NULL,
    IdBaseLegacy   tinyint     NULL,   -- CABD_ID_BASE del .exe (15..27)
    IdDepartamento tinyint     NULL,   -- departamento operativo de la cartera
    Activo         bit         NOT NULL CONSTRAINT DF_Cartera_Activo DEFAULT (1),
    FechaRegistro  datetime2(0) NOT NULL CONSTRAINT DF_Cartera_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT FK_Cartera_Cliente FOREIGN KEY (IdCliente) REFERENCES cart.Cliente (IdCliente),
    CONSTRAINT FK_Cartera_Departamento FOREIGN KEY (IdDepartamento) REFERENCES rh.Departamento (IdDepartamento),
    CONSTRAINT UQ_Cartera_IdBaseLegacy UNIQUE (IdBaseLegacy)
);
GO

-- ---------- Semilla de puestos ----------
;WITH Puestos AS (
    SELECT * FROM (VALUES
        (1,  'DIRECTOR GENERAL',                'DG', 1),
        (2,  'DIRECTOR COMERCIAL',              'DC', 2),
        (3,  'GERENTE DE AUDITORIA',            'GA', 5),
        (4,  'GERENTE DE RRHH',                 'GR', 4),
        (5,  'GERENTE DE OPERACION',            'GO', 8),
        (6,  'GERENTE DE CALIDAD',              'GC', 6),
        (7,  'GERENTE DE SISTEMAS',             'GS', 7),
        (8,  'ADMINISTRATIVO',                  '',   0),
        (9,  'PERSONAL DE MANTENIMIENTO',       '',   0),
        (10, 'SOPORTE TECNICO PC''S',           'GS', 0),
        (11, 'SOPORTE EN TELECOMUNICACIONES',   'GS', 0),
        (12, 'SOPORTE EN REDES',                'GS', 0),
        (13, 'ANALISTA DE DATOS',               'GS', 0),
        (14, 'EJECUTIVO TELEFONICO',            'DO', 0),
        (15, 'VISITADOR',                       'DO', 0),
        (16, 'COODINADOR DE CARTERA',           'DO', 0),
        (17, 'SUPERVISOR DE CARTERA',           'DO', 0),
        (18, 'MONITORISTA',                     'GC', 0),
        (19, 'PROGRAMADOR BACK',                'GS', 0),
        (20, 'PROGRAMADOR FRONT',               'GS', 0),
        (21, 'ADMINISTRADOR DE BASE DE DATOS',  'GS', 0),
        (22, 'SISTEMAS DE INFORMACION GERENCIAL','',  0),
        (23, 'COORDINADOR DE CALIDAD',          'GC', 0),
        (24, 'COORDINADOR DE VISITAS',          'DO', 0),
        (25, 'RECLUTADOR',                      'GR', 0),
        (26, 'DIRECTOR OPERACIONES',            'DO', 3),
        (27, 'PROJECT MANAGER',                 'PM', 0),
        (28, 'MONITOR DE CALIDAD',              'GC', 0),
        (29, 'EJECUTIVO MULTICARTERA',          'DO', 0)
    ) AS v (IdPuesto, Nombre, Tipo, Gerarquia)
)
INSERT INTO rh.Puesto (IdPuesto, Nombre, Tipo, Gerarquia)
SELECT p.IdPuesto, p.Nombre, p.Tipo, p.Gerarquia
FROM Puestos p
WHERE NOT EXISTS (SELECT 1 FROM rh.Puesto x WHERE x.IdPuesto = p.IdPuesto);
GO

-- ---------- Semilla de departamentos ----------
;WITH Departamentos AS (
    SELECT * FROM (VALUES
        (1,  'DESARROLLO ORGANIZACIONAL',   'R'),
        (2,  'CONTRATACIONES',              'R'),
        (3,  'MONITOREO',                   'C'),
        (4,  'DESARROLLO',                  'S'),
        (5,  'REDES',                       'S'),
        (6,  'SOPORTE',                     'S'),
        (7,  'PROCESOS',                    'S'),
        (8,  'TELECOMUNICACIONES',          'S'),
        (9,  'MIS',                         'S'),
        (10, 'VISITAS',                     'O'),
        (11, 'NOMINA',                      'R'),
        (12, 'ADMINISTRACION',              'G'),
        (13, 'PROYECT MANAGER',             'P'),
        (14, 'BANCO_AZTECA',                'O'),
        (15, 'BAZ_FRANQUICIA',              'O'),
        (16, 'BAZ_MOVILIDAD',               'O'),
        (17, 'MBA',                         'O'),
        (18, 'KUBO',                        'O'),
        (19, 'BAZ_EXEMPLEADOS',             'O'),
        (20, 'TOTAL PLAY',                  'O'),
        (21, 'CONCREDITO',                  'O'),
        (22, 'SEARS',                       'O'),
        (23, 'SANBORNS',                    'O'),
        (28, 'INBURSA_FIANZAS_TELCEL',      'O'),
        (29, 'LSF_PRESTAMOS_PERSONALES',    'O')
    ) AS v (IdDepartamento, Nombre, Tipo)
)
INSERT INTO rh.Departamento (IdDepartamento, Nombre, Tipo)
SELECT d.IdDepartamento, d.Nombre, d.Tipo
FROM Departamentos d
WHERE NOT EXISTS (SELECT 1 FROM rh.Departamento x WHERE x.IdDepartamento = d.IdDepartamento);
GO

-- ---------- Semilla de sexo y turno ----------
INSERT INTO cat.Sexo (IdSexo, Nombre)
SELECT v.IdSexo, v.Nombre
FROM (VALUES (1, 'MASCULINO'), (2, 'FEMENINO'), (3, 'OTRO')) AS v (IdSexo, Nombre)
WHERE NOT EXISTS (SELECT 1 FROM cat.Sexo x WHERE x.IdSexo = v.IdSexo);
GO

INSERT INTO cat.Turno (IdTurno, Nombre)
SELECT v.IdTurno, v.Nombre
FROM (VALUES
    (1, 'Matutino'), (2, 'Vespertino'), (3, 'Completo'),
    (4, 'Nocturno'), (5, 'Estudiantes'), (6, 'Intermedio')
) AS v (IdTurno, Nombre)
WHERE NOT EXISTS (SELECT 1 FROM cat.Turno x WHERE x.IdTurno = v.IdTurno);
GO

-- ---------- Semilla de clientes ----------
INSERT INTO cart.Cliente (IdCliente, Nombre)
SELECT v.IdCliente, v.Nombre
FROM (VALUES
    (1,  'BANCO_AZTECA'),
    (2,  'BAZ_FRANQUICIA'),
    (3,  'BAZ_MOVILIDAD'),
    (4,  'NETMSYST_DEMO'),
    (5,  'MBA'),
    (6,  'KUBO'),
    (7,  'BAZ_EXEMPLEADOS'),
    (8,  'TOTAL_PLAY'),
    (9,  'CONCREDITO'),
    (10, 'SEARS'),
    (11, 'SANBORNS'),
    (12, 'INBURSA_FIANZAS_TELCEL'),
    (13, 'LSF_PRESTAMOS_PERSONALES')
) AS v (IdCliente, Nombre)
WHERE NOT EXISTS (SELECT 1 FROM cart.Cliente x WHERE x.IdCliente = v.IdCliente);
GO

-- ---------- Semilla de carteras ----------
INSERT INTO cart.Cartera (IdCartera, IdCliente, Nombre, IdBaseLegacy, IdDepartamento)
SELECT v.IdCartera, v.IdCliente, v.Nombre, v.IdBaseLegacy, v.IdDepartamento
FROM (VALUES
    (1,  1,  'BANCO_AZTECA',             15, CAST(14 AS tinyint)),
    (2,  2,  'BAZ_FRANQUICIA',           16, CAST(15 AS tinyint)),
    (3,  3,  'BAZ_MOVILIDAD',            17, CAST(16 AS tinyint)),
    (4,  4,  'NETMSYST_DEMO',            18, CAST(NULL AS tinyint)),
    (5,  5,  'MBA',                      19, CAST(17 AS tinyint)),
    (6,  6,  'KUBO',                     20, CAST(18 AS tinyint)),
    (7,  7,  'BAZ_EXEMPLEADOS',          21, CAST(19 AS tinyint)),
    (8,  8,  'TOTAL_PLAY',               22, CAST(20 AS tinyint)),
    (9,  9,  'CONCREDITO',               23, CAST(21 AS tinyint)),
    (10, 10, 'SEARS',                    24, CAST(22 AS tinyint)),
    (11, 11, 'SANBORNS',                 25, CAST(23 AS tinyint)),
    (12, 12, 'INBURSA_FIANZAS_TELCEL',   26, CAST(28 AS tinyint)),
    (13, 13, 'LSF_PRESTAMOS_PERSONALES', 27, CAST(29 AS tinyint))
) AS v (IdCartera, IdCliente, Nombre, IdBaseLegacy, IdDepartamento)
WHERE NOT EXISTS (SELECT 1 FROM cart.Cartera x WHERE x.IdCartera = v.IdCartera);
GO

PRINT 'Catalogos y carteras listos (puestos, departamentos, sexo, turno, clientes, carteras).';
GO
