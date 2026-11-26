/*
  BABEL_CRM - 01. Crea la base unica del CRM y sus esquemas por tema.
  Ejecutar en el SQL local (localhost). Idempotente: se puede correr varias veces.

  Esquemas:
    seg  - Seguridad (usuarios, perfiles, accesos)
    rh   - Recursos Humanos (empleados, puestos, departamentos)
    cart - Carteras y asignacion de personal
    adm  - Administracion (filas de trabajo, textos)
    log  - Bitacora propia del CRM

  Nota: todas las tablas de negocio llevan IdCliente para distinguir clientes
  dentro de UNA sola base (en lugar de una base por cliente).
*/
IF DB_ID('BABEL_CRM') IS NULL
BEGIN
    CREATE DATABASE BABEL_CRM;
    PRINT 'Base BABEL_CRM creada.';
END
ELSE
    PRINT 'Base BABEL_CRM ya existia.';
GO

USE BABEL_CRM;
GO

IF SCHEMA_ID('seg')  IS NULL EXEC('CREATE SCHEMA seg');
IF SCHEMA_ID('rh')   IS NULL EXEC('CREATE SCHEMA rh');
IF SCHEMA_ID('cart') IS NULL EXEC('CREATE SCHEMA cart');
IF SCHEMA_ID('adm')  IS NULL EXEC('CREATE SCHEMA adm');
IF SCHEMA_ID('log')  IS NULL EXEC('CREATE SCHEMA log');
GO

-- Catalogo de clientes (reemplaza la "base por cliente" por un dato IdCliente)
IF OBJECT_ID('seg.Cliente') IS NULL
BEGIN
    CREATE TABLE seg.Cliente (
        IdCliente   int           NOT NULL PRIMARY KEY,
        Nombre      nvarchar(100) NOT NULL,
        Activo      bit           NOT NULL CONSTRAINT DF_Cliente_Activo DEFAULT(1)
    );
    PRINT 'Tabla seg.Cliente creada.';
END
GO
