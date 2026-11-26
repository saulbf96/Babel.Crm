<#
  BABEL_UNIFICADA - 10. Migración operativa de MUESTRA (prueba manual).

  Copia una muestra representativa de BANCO_AZTECA (cartera 1) desde
  10.80.5.189 hacia BABEL_UNIFICADA, con control en mig.ControlCarga.

  REGLA CRÍTICA: en 10.80.5.189 SOLO se ejecutan SELECT. Nunca BACKUP,
  INSERT, UPDATE ni DELETE en el servidor remoto. Toda escritura es local.

  La contraseña se lee del XML de configuración y NUNCA se imprime.

  Uso:
    powershell -ExecutionPolicy Bypass -File database\BABEL_UNIFICADA\10_mig_operativo_muestra.ps1
#>
$ErrorActionPreference = 'Stop'

$configXml = 'C:\Users\sbasilio\Desktop\Trabajos\ingenieria inversa\APLICATIVOS\analysis\BABELGESTION.xml'
[xml]$config = Get-Content -Path $configXml -Encoding UTF8
$hostRemoto = $config.SelectSingleNode('/BBDD/Server/Host').InnerText
$puertoRemoto = $config.SelectSingleNode('/BBDD/Server/Port').InnerText
$usuarioRemoto = $config.SelectSingleNode('/BBDD/Server/Usuario').InnerText
$passwordRemoto = $config.SelectSingleNode('/BBDD/Server/Password').InnerText
$baseRemota = 'BANCO_AZTECA'
$idCartera = 1
$tope = 150
$nombreCarga = "MUESTRA_BANCO_AZTECA_$tope"

$cadenaLocal = 'Server=localhost;Database=BABEL_UNIFICADA;Integrated Security=True;TrustServerCertificate=True;Encrypt=False;'
$cadenaRemota = "Server=$hostRemoto,$puertoRemoto;User ID=$usuarioRemoto;Password=$passwordRemoto;Database=$baseRemota;TrustServerCertificate=True;Encrypt=False;"

function Invoke-Sql {
    param([string]$Cadena, [string]$Sql, [switch]$Tabla)
    $cn = New-Object System.Data.SqlClient.SqlConnection($Cadena)
    try {
        $cn.Open()
        $cmd = $cn.CreateCommand()
        $cmd.CommandText = $Sql
        $cmd.CommandTimeout = 600
        if ($Tabla) {
            $da = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
            $dt = New-Object System.Data.DataTable
            [void]$da.Fill($dt)
            Write-Output -NoEnumerate $dt
            return
        }
        [void]$cmd.ExecuteNonQuery()
        return
    }
    finally { $cn.Dispose() }
}

function Escribe-Mensaje {
    param([string]$Texto)
    Write-Host $Texto
}

# ---------------------------------------------------------------------------
# 1. Tablas de preparación (staging) en el esquema local mig.
# ---------------------------------------------------------------------------
Escribe-Mensaje 'Preparando tablas de staging...'
Invoke-Sql -Cadena $cadenaLocal -Sql @'
IF OBJECT_ID('mig.StgDemografico') IS NOT NULL DROP TABLE mig.StgDemografico;
IF OBJECT_ID('mig.StgPromesa')     IS NOT NULL DROP TABLE mig.StgPromesa;
IF OBJECT_ID('mig.StgGestion')     IS NOT NULL DROP TABLE mig.StgGestion;
IF OBJECT_ID('mig.StgTelefono')    IS NOT NULL DROP TABLE mig.StgTelefono;
IF OBJECT_ID('mig.StgCuenta')      IS NOT NULL DROP TABLE mig.StgCuenta;

CREATE TABLE mig.StgCuenta (
    IdControl int NOT NULL, Numero varchar(30) NULL, Cliente varchar(60) NULL,
    Situacion smallint NULL, Saldo decimal(18,2) NULL, IdEmpleado int NULL,
    GestionDesc varchar(800) NULL, FechaCarga datetime NULL);
CREATE TABLE mig.StgTelefono (
    IdBaseTel bigint NOT NULL, IdControl int NOT NULL, Numero varchar(10) NULL,
    Tipo varchar(15) NULL, Lada smallint NULL, Prefijo smallint NULL, Activo bit NULL);
CREATE TABLE mig.StgGestion (
    IdGestion bigint NOT NULL, IdControl int NOT NULL, IdEmpleado int NULL,
    IdStatus tinyint NULL, IdIntegracion bigint NULL,
    FechaGestion smalldatetime NULL, HoraInicio datetime NULL, HoraFin datetime NULL,
    TelefonoMarcado varchar(10) NULL, Comentario varchar(8000) NULL,
    TiempoLlamada smallint NULL, TiempoEscritura smallint NULL, Inbound bit NULL);
CREATE TABLE mig.StgPromesa (
    IdPromesa bigint NOT NULL, IdControl int NOT NULL, IdGestion bigint NULL,
    FechaPromesa datetime NULL, Monto decimal(18,2) NULL, Lugar varchar(70) NULL, Activo bit NULL);
CREATE TABLE mig.StgDemografico (
    IdDemo int NOT NULL, IdControl int NOT NULL, Calle varchar(200) NULL,
    Colonia varchar(200) NULL, CP varchar(10) NULL, ColoniaMunicipio varchar(200) NULL,
    Municipio varchar(200) NULL, Activo bit NULL);
'@

# ---------------------------------------------------------------------------
# 2. Leer CUENTAS del remoto (SELECT) y copiarlas al staging local.
# ---------------------------------------------------------------------------
Escribe-Mensaje "Leyendo $tope cuentas de $baseRemota (solo SELECT)..."
$sqlCuentas = @"
SELECT TOP ($tope) NECU_ID_CONTROL AS IdControl, NECU_CUENTA AS Numero,
       NECU_NOMBRE_CLIENTE AS Cliente, NECU_ID_SITUACION_CUENTA AS Situacion,
       NECU_SALDO AS Saldo, NECU_ID_EMPLEADO AS IdEmpleado,
       NECU_GESTION_DESC AS GestionDesc, NECU_FECHA_CARGA AS FechaCarga
FROM NECU_DATOSCUENTA
ORDER BY NECU_ID_CONTROL;
"@
$dt = Invoke-Sql -Cadena $cadenaRemota -Sql $sqlCuentas -Tabla
$bulk = New-Object System.Data.SqlClient.SqlBulkCopy($cadenaLocal)
$bulk.DestinationTableName = 'mig.StgCuenta'
$bulk.BatchSize = 500
$bulk.BulkCopyTimeout = 600
[void]$bulk.WriteToServer($dt)
$bulk.Dispose()
Escribe-Mensaje "  Cuentas en staging: $($dt.Rows.Count)"

# Lista de controles para filtrar el resto de entidades.
$lista = New-Object System.Collections.Generic.List[string]
foreach ($fila in $dt.Rows) { [void]$lista.Add([string]$fila[0]) }
$controles = [string]::Join(',', $lista)
if ([string]::IsNullOrWhiteSpace($controles)) { throw 'No se leyeron cuentas; se detiene la migración.' }

$idCarga = (Invoke-Sql -Cadena $cadenaLocal -Tabla -Sql @"
EXEC mig.USP_INICIA_CARGA @NombreCarga='$nombreCarga', @OrigenServidor='$hostRemoto',
     @OrigenBase='$baseRemota', @Entidad='Cuenta', @Usuario='MIGRACION', @FilasLeidas=$($dt.Rows.Count);
"@).Rows[0][0]

Invoke-Sql -Cadena $cadenaLocal -Sql @"
SET XACT_ABORT ON;
BEGIN TRAN;

DELETE d FROM ope.Demografico d JOIN ope.Cuenta c ON c.IdCuenta=d.IdCuenta
 WHERE c.IdCartera=$idCartera AND c.IdControlLegacy > 0;
DELETE p FROM ope.Promesa p JOIN ope.Cuenta c ON c.IdCuenta=p.IdCuenta
 WHERE c.IdCartera=$idCartera AND c.IdControlLegacy > 0;
DELETE g FROM ope.Gestion g JOIN ope.Cuenta c ON c.IdCuenta=g.IdCuenta
 WHERE c.IdCartera=$idCartera AND c.IdControlLegacy > 0;
DELETE t FROM ope.Telefono t JOIN ope.Cuenta c ON c.IdCuenta=t.IdCuenta
 WHERE c.IdCartera=$idCartera AND c.IdControlLegacy > 0;
DELETE FROM ope.Cuenta WHERE IdCartera=$idCartera AND IdControlLegacy > 0;

INSERT INTO ope.Cuenta
 (IdCartera, IdControlLegacy, NumeroCuenta, NombreCliente, SituacionCuenta,
  RazonMora, Saldo, IdEmpleado, FechaRegistro)
SELECT $idCartera, s.IdControl,
       ISNULL(NULLIF(LTRIM(RTRIM(s.Numero)),''), CONCAT('C', s.IdControl)),
       NULLIF(LTRIM(RTRIM(s.Cliente)),''),
       CONCAT('Situacion legacy ', ISNULL(s.Situacion, 0)),
       LEFT(NULLIF(LTRIM(RTRIM(s.GestionDesc)),''), 100),
       s.Saldo,
       ISNULL((SELECT TOP (1) e.IdEmpleado FROM rh.Empleado e WHERE e.IdEmpleado=s.IdEmpleado), 6),
       ISNULL(s.FechaCarga, SYSDATETIME())
FROM mig.StgCuenta s
WHERE NOT EXISTS (SELECT 1 FROM ope.Cuenta x
                  WHERE x.IdCartera=$idCartera AND x.IdControlLegacy=s.IdControl);
COMMIT;
"@
$insertadas = (Invoke-Sql -Cadena $cadenaLocal -Sql "SELECT COUNT(*) FROM ope.Cuenta WHERE IdCartera=$idCartera AND IdControlLegacy IN (SELECT IdControl FROM mig.StgCuenta);" -Tabla).Rows[0][0]
Invoke-Sql -Cadena $cadenaLocal -Sql "EXEC mig.USP_FINALIZA_CARGA @IdCarga=$idCarga, @FilasInsertadas=$insertadas, @Detalle='Muestra de cuentas';"

# Helper: leer entidad, copiar a staging, volcar a ope.* y registrar carga.
function Migrar-Entidad {
    param(
        [string]$Entidad, [string]$SqlRemoto, [string]$TablaStaging,
        [string[]]$Columnas, [string]$SqlDestino, [string]$Detalle
    )
    Escribe-Mensaje "Leyendo $Entidad (solo SELECT)..."
    $origen = Invoke-Sql -Cadena $cadenaRemota -Sql $SqlRemoto -Tabla
    if ($origen.Rows.Count -eq 0) { Escribe-Mensaje '  Sin filas.'; return }

    Invoke-Sql -Cadena $cadenaLocal -Sql "TRUNCATE TABLE $TablaStaging;"
    $b = New-Object System.Data.SqlClient.SqlBulkCopy($cadenaLocal)
    $b.DestinationTableName = $TablaStaging
    $b.BatchSize = 1000
    $b.BulkCopyTimeout = 600
    for ($i = 0; $i -lt $Columnas.Count; $i++) {
        [void]$b.ColumnMappings.Add($Columnas[$i], $Columnas[$i])
    }
    [void]$b.WriteToServer($origen)
    $b.Dispose()

    $carga = (Invoke-Sql -Cadena $cadenaLocal -Tabla -Sql @"
EXEC mig.USP_INICIA_CARGA @NombreCarga='$nombreCarga', @OrigenServidor='$hostRemoto',
     @OrigenBase='$baseRemota', @Entidad='$Entidad', @Usuario='MIGRACION', @FilasLeidas=$($origen.Rows.Count);
"@).Rows[0][0]
    Invoke-Sql -Cadena $cadenaLocal -Sql $SqlDestino
    $ins = (Invoke-Sql -Cadena $cadenaLocal -Sql "SELECT COUNT(*) FROM $TablaStaging;" -Tabla).Rows[0][0]
    Invoke-Sql -Cadena $cadenaLocal -Sql "EXEC mig.USP_FINALIZA_CARGA @IdCarga=$carga, @FilasInsertadas=$ins, @Detalle='$Detalle';"
    Escribe-Mensaje "  $Entidad`: $($origen.Rows.Count) filas leidas, $ins insertadas."
}

Migrar-Entidad -Entidad 'Telefono' -TablaStaging 'mig.StgTelefono' -Detalle 'Muestra de telefonos' `
  -SqlRemoto "SELECT NEBT_ID_BASE_TEL AS IdBaseTel, NEBT_ID_CONTROL AS IdControl, NEBT_TELEFONO AS Numero, NEBT_TIPO_TEL AS Tipo, NEBT_LADA AS Lada, NEBT_PREFIJO AS Prefijo, NEBT_ACTIVO AS Activo FROM NEBT_BASE_TELEFONICA WHERE NEBT_ID_CONTROL IN ($controles);" `
  -Columnas @('IdBaseTel','IdControl','Numero','Tipo','Lada','Prefijo','Activo') `
  -SqlDestino @"
INSERT INTO ope.Telefono (IdCuenta, IdCartera, Numero, Tipo, Origen, IdRegistroLegacy, Activo)
SELECT c.IdCuenta, $idCartera,
       ISNULL(NULLIF(LTRIM(RTRIM(s.Numero)),''), CONCAT('S', s.IdBaseTel)),
       NULLIF(LTRIM(RTRIM(s.Tipo)),''),
       CONCAT('Lada ', ISNULL(s.Lada,0), ' / Prefijo ', ISNULL(s.Prefijo,0)),
       s.IdBaseTel, ISNULL(s.Activo,1)
FROM mig.StgTelefono s
JOIN ope.Cuenta c ON c.IdCartera=$idCartera AND c.IdControlLegacy=s.IdControl
WHERE NOT EXISTS (SELECT 1 FROM ope.Telefono t
                  WHERE t.IdCartera=$idCartera AND t.IdRegistroLegacy=s.IdBaseTel);
"@

Migrar-Entidad -Entidad 'Gestion' -TablaStaging 'mig.StgGestion' -Detalle 'Muestra de gestiones; tipo legacy se preserva en Comentario' `
  -SqlRemoto "SELECT NEGE_ID_GESTION AS IdGestion, NEGE_ID_CONTROL AS IdControl, NEGE_ID_EMPLEADO AS IdEmpleado, NEGE_ID_STATUS AS IdStatus, NEGE_ID_INTEGRACION AS IdIntegracion, NEGE_FECHA_GESTION AS FechaGestion, NEGE_HORA_INICIO_GESTION AS HoraInicio, NEGE_HORA_FIN_GESTION AS HoraFin, NEGE_TELEFONO_MARCADO AS TelefonoMarcado, NEGE_COMENTARIO AS Comentario, NEGE_TIEMPO_LLAMADA AS TiempoLlamada, NEGE_TIEMPO_ESCRITURA AS TiempoEscritura, NEGE_INBOUND AS Inbound FROM NEGE_GESTION WHERE NEGE_ID_CONTROL IN ($controles);" `
  -Columnas @('IdGestion','IdControl','IdEmpleado','IdStatus','IdIntegracion','FechaGestion','HoraInicio','HoraFin','TelefonoMarcado','Comentario','TiempoLlamada','TiempoEscritura','Inbound') `
  -SqlDestino @"
INSERT INTO ope.Gestion
 (IdCuenta, IdCartera, IdEmpleado, IdTipoGestion, TelefonoMarcado, Comentario,
  Inbound, FechaInicio, FechaFin, TiempoLlamadaSegundos, TiempoEscrituraSegundos,
  IdIntegracionLegacy, IdRegistroLegacy)
SELECT c.IdCuenta, $idCartera,
       ISNULL((SELECT TOP (1) e.IdEmpleado FROM rh.Empleado e WHERE e.IdEmpleado=s.IdEmpleado), 6),
       1,
       NULLIF(LTRIM(RTRIM(s.TelefonoMarcado)),''),
       CONCAT('[Status legacy ', ISNULL(s.IdStatus,0), '] ', ISNULL(s.Comentario,'')),
       ISNULL(s.Inbound,0),
       ISNULL(s.HoraInicio, CAST(s.FechaGestion AS datetime2(0))), s.HoraFin,
       s.TiempoLlamada, s.TiempoEscritura, s.IdIntegracion, s.IdGestion
FROM mig.StgGestion s
JOIN ope.Cuenta c ON c.IdCartera=$idCartera AND c.IdControlLegacy=s.IdControl
WHERE NOT EXISTS (SELECT 1 FROM ope.Gestion g
                  WHERE g.IdCartera=$idCartera AND g.IdRegistroLegacy=s.IdGestion);
"@

Migrar-Entidad -Entidad 'Promesa' -TablaStaging 'mig.StgPromesa' -Detalle 'Muestra de promesas de pago' `
  -SqlRemoto "SELECT NEPR_ID_PROMESA AS IdPromesa, NEPR_ID_CONTROL AS IdControl, NEPR_ID_GESTION AS IdGestion, NEPR_FECHA_PROMESA_PAGO AS FechaPromesa, NEPR_MONTO_PROMESA_PAGO AS Monto, NEPR_LUGAR AS Lugar, NEPR_ACTIVO AS Activo FROM NEPR_PROMESAS WHERE NEPR_ID_CONTROL IN ($controles);" `
  -Columnas @('IdPromesa','IdControl','IdGestion','FechaPromesa','Monto','Lugar','Activo') `
  -SqlDestino @"
INSERT INTO ope.Promesa
 (IdCuenta, IdCartera, Monto, FechaPromesa, LugarPago, Estatus, IdRegistroLegacy)
SELECT c.IdCuenta, $idCartera, ISNULL(s.Monto,0),
       CAST(ISNULL(s.FechaPromesa, GETDATE()) AS date),
       NULLIF(LTRIM(RTRIM(s.Lugar)),''),
       CASE WHEN ISNULL(s.Activo,1)=1 THEN 'PENDIENTE' ELSE 'CANCELADA' END,
       s.IdPromesa
FROM mig.StgPromesa s
JOIN ope.Cuenta c ON c.IdCartera=$idCartera AND c.IdControlLegacy=s.IdControl
WHERE NOT EXISTS (SELECT 1 FROM ope.Promesa p
                  WHERE p.IdCartera=$idCartera AND p.IdRegistroLegacy=s.IdPromesa);
"@

Migrar-Entidad -Entidad 'Demografico' -TablaStaging 'mig.StgDemografico' -Detalle 'Muestra de demographicos' `
  -SqlRemoto "SELECT NEDE_ID_DEMOGRAFICO AS IdDemo, NEDE_ID_CONTROL AS IdControl, NEDE_CALLE AS Calle, NEDE_COLONIA AS Colonia, NEDE_CP AS CP, NEDE_DEL_MUN AS ColoniaMunicipio, NEDE_MUNICIPIO AS Municipio, NEDE_ACTIVO AS Activo FROM NEDE_DEMOGRAFICOS WHERE NEDE_ID_CONTROL IN ($controles);" `
  -Columnas @('IdDemo','IdControl','Calle','Colonia','CP','ColoniaMunicipio','Municipio','Activo') `
  -SqlDestino @"
INSERT INTO ope.Demografico
 (IdCuenta, IdCartera, Calle, Colonia, CodigoPostal, Delegacion, Estado, IdRegistroLegacy)
SELECT c.IdCuenta, $idCartera,
       NULLIF(LTRIM(RTRIM(s.Calle)),''), NULLIF(LTRIM(RTRIM(s.Colonia)),''),
       NULLIF(LTRIM(RTRIM(s.CP)),''), NULLIF(LTRIM(RTRIM(s.ColoniaMunicipio)),''),
       NULLIF(LTRIM(RTRIM(s.Municipio)),''), s.IdDemo
FROM mig.StgDemografico s
JOIN ope.Cuenta c ON c.IdCartera=$idCartera AND c.IdControlLegacy=s.IdControl
WHERE NOT EXISTS (SELECT 1 FROM ope.Demografico d
                  WHERE d.IdCartera=$idCartera AND d.IdRegistroLegacy=s.IdDemo);
"@

# ---------------------------------------------------------------------------
# 3. Verificación local.
# ---------------------------------------------------------------------------
Escribe-Mensaje ''
Escribe-Mensaje '--- Conteos finales en BABEL_UNIFICADA (cartera 1) ---'
$ver = Invoke-Sql -Cadena $cadenaLocal -Sql @"
SET NOCOUNT ON;
SELECT 'ope.Cuenta' Entidad, COUNT(*) Filas FROM ope.Cuenta WHERE IdCartera=$idCartera
UNION ALL SELECT 'ope.Telefono', COUNT(*) FROM ope.Telefono WHERE IdCartera=$idCartera
UNION ALL SELECT 'ope.Gestion', COUNT(*) FROM ope.Gestion WHERE IdCartera=$idCartera
UNION ALL SELECT 'ope.Promesa', COUNT(*) FROM ope.Promesa WHERE IdCartera=$idCartera
UNION ALL SELECT 'ope.Demografico', COUNT(*) FROM ope.Demografico WHERE IdCartera=$idCartera;
SELECT IdCarga, Entidad, FilasLeidas, FilasInsertadas, Estatus
FROM mig.ControlCarga WHERE NombreCarga='$nombreCarga' ORDER BY IdCarga;
"@ -Tabla
$ver | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
Escribe-Mensaje 'Migración de muestra terminada.'
