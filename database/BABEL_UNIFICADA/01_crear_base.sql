/*
  BABEL_UNIFICADA - 01. Crea la base unica del CRM y sus esquemas por dominio.
  Ejecutar en el SQL local (localhost). Idempotente: se puede correr varias veces.

  Esta base reemplaza el esquema de "una base por cartera". Todas las tablas de
  negocio llevan IdCartera para distinguir la cartera dentro de UNA sola base.

  Esquemas:
    seg  - Seguridad (usuarios, sesion, accesos)
    rh   - Recursos Humanos (empleados, puestos, departamentos, asignacion)
    cart - Clientes, carteras y personal asignado
    ope  - Operacion (personal en operativo, filas de trabajo)
    adm  - Administracion (cargas, procesos, configuracion)
    cat  - Catalogos generales (sexo, turno)
    log  - Bitacora y auditoria del CRM

  La base se crea LIMPIA: solo catalogos y el usuario ADMIN de arranque.
  Los datos operativos se migran despues desde las bases restauradas.
*/
IF DB_ID('BABEL_UNIFICADA') IS NULL
BEGIN
    CREATE DATABASE BABEL_UNIFICADA;
    PRINT 'Base BABEL_UNIFICADA creada.';
END
ELSE
    PRINT 'Base BABEL_UNIFICADA ya existia.';
GO

USE BABEL_UNIFICADA;
GO

IF SCHEMA_ID('seg')  IS NULL EXEC('CREATE SCHEMA seg');
IF SCHEMA_ID('rh')   IS NULL EXEC('CREATE SCHEMA rh');
IF SCHEMA_ID('cart') IS NULL EXEC('CREATE SCHEMA cart');
IF SCHEMA_ID('ope')  IS NULL EXEC('CREATE SCHEMA ope');
IF SCHEMA_ID('adm')  IS NULL EXEC('CREATE SCHEMA adm');
IF SCHEMA_ID('cat')  IS NULL EXEC('CREATE SCHEMA cat');
IF SCHEMA_ID('log')  IS NULL EXEC('CREATE SCHEMA log');
GO

-- Bitacora de acciones administrativas (altas, cambios de cartera, asignaciones).
IF OBJECT_ID('log.Auditoria') IS NULL
CREATE TABLE log.Auditoria (
    IdAuditoria bigint        NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Usuario     varchar(50)   NULL,
    Accion      varchar(100)  NOT NULL,
    Entidad     varchar(100)  NOT NULL,
    IdEntidad   varchar(50)   NULL,
    Detalle     nvarchar(max) NULL,
    Fecha       datetime2(0)  NOT NULL CONSTRAINT DF_Auditoria_Fecha DEFAULT (SYSDATETIME()),
    Ip          varchar(45)   NULL
);
GO

PRINT 'Esquemas y bitacora listos en BABEL_UNIFICADA.';
GO
