<#
  BABEL_UNIFICADA - 11. Migración operativa COMPLETA de las 13 carteras.

  Copia las tablas operativas de cada base de cartera de 10.80.5.189 a
  BABEL_UNIFICADA, por lotes, con control en mig.ControlCarga.

  REGLA CRÍTICA: en 10.80.5.189 SOLO se ejecutan SELECT. Nunca BACKUP,
  INSERT, UPDATE ni DELETE en el remoto. Toda escritura es local.
  La contraseña se lee del XML y NUNCA se imprime.

  Uso:
    powershell -NoProfile -ExecutionPolicy Bypass -File database\BABEL_UNIFICADA\11_mig_operativo_completo.ps1
#>
$ErrorActionPreference = 'Stop'

$configXml = 'C:\Users\sbasilio\Desktop\Trabajos\ingenieria inversa\APLICATIVOS\analysis\BABELGESTION.xml'
[xml]$config = Get-Content -Path $configXml -Encoding UTF8
$hostRemoto = $config.SelectSingleNode('/BBDD/Server/Host').InnerText
$puertoRemoto = $config.SelectSingleNode('/BBDD/Server/Port').InnerText
$usuarioRemoto = $config.SelectSingleNode('/BBDD/Server/Usuario').InnerText
$passwordRemoto = $config.SelectSingleNode('/BBDD/Server/Password').InnerText

$cadenaLocal = 'Server=localhost;Database=BABEL_UNIFICADA;Integrated Security=True;TrustServerCertificate=True;Encrypt=False;'
$nombreCarga = 'OPERATIVO_COMPLETO_13_CARTERAS'
$lote = 100000

function Invoke-Sql {
    param([string]$Cadena, [string]$Sql, [switch]$Tabla)
    $cn = New-Object System.Data.SqlClient.SqlConnection($Cadena)
    try {
        $cn.Open()
        $cmd = $cn.CreateCommand()
        $cmd.CommandText = $Sql
        $cmd.CommandTimeout = 1200
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

function Cadena-Remota {
    param([string]$Base)
    return "Server=$hostRemoto,$puertoRemoto;User ID=$usuarioRemoto;Password=$passwordRemoto;Database=$Base;TrustServerCertificate=True;Encrypt=False;"
}

function Escribe {
    param([string]$Texto)
    Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Texto)
}

# Cada cartera tiene un layout distinto en NECU_DATOSCUENTA. Consultamos el
# esquema remoto (SELECT a INFORMATION_SCHEMA) y elegimos la primera columna
# equivalente que exista; si no hay ninguna, migramos NULL en lugar de fallar.
function ObtenerColumnasRemotas {
    param([string]$Cadena)
    $datos = Invoke-Sql -Cadena $Cadena -Tabla -Sql @'
SELECT DISTINCT COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN ('NECU_DATOSCUENTA','NEBT_BASE_TELEFONICA','NEGE_GESTION',
                    'NEPR_PROMESAS','NEDE_DEMOGRAFICOS');
'@
    return @($datos.Rows | ForEach-Object { [string]$_[0] })
}

function ExpresionSaldo {
    param([string[]]$Columnas)
    $candidatos = @(
        'NECU_SALDO', 'NECU_SALDOACTUAL', 'NECU_SALDO_ACT', 'NECU_SALDO_CAPITAL',
        'NECU_SALDOCAPITAL', 'NECU_SALDO_TOTAL', 'NECU_SALDOTOTAL',
        'NECU_TOTAL_CARTERA', 'NECU_TOTALLIQUIDA', 'NECU_IMPORTE',
        'NECU_MONTO_TOTAL_INTEGRANTE'
    )
    foreach ($columna in $candidatos) {
        if ($Columnas -contains $columna) { return "TRY_CONVERT(decimal(18,2), $columna)" }
    }
    return 'CAST(NULL AS decimal(18,2))'
}

function ExpresionGestion {
    param([string[]]$Columnas)
    $candidatos = @(
        'NECU_GESTION_DESC', 'NECU_FC_DESCRIP_GESTION', 'NECU_ULTIMA_GESTION',
        'NECU_ESTATUS_PLAN', 'NECU_ESTATUS_CTA', 'NECU_ESTRATEGIA'
    )
    foreach ($columna in $candidatos) {
        if ($Columnas -contains $columna) { return "TRY_CONVERT(varchar(800), $columna)" }
    }
    return 'CAST(NULL AS varchar(800))'
}

# ---------------------------------------------------------------------------
# 1. Preparación local: staging, indices y limpieza de cargas anteriores.
# ---------------------------------------------------------------------------
Escribe 'Preparando staging e indices locales...'
Invoke-Sql -Cadena $cadenaLocal -Sql @'
IF OBJECT_ID('mig.StgDemografico') IS NOT NULL DROP TABLE mig.StgDemografico;
IF OBJECT_ID('mig.StgPromesa')     IS NOT NULL DROP TABLE mig.StgPromesa;
IF OBJECT_ID('mig.StgGestion')     IS NOT NULL DROP TABLE mig.StgGestion;
IF OBJECT_ID('mig.StgTelefono')    IS NOT NULL DROP TABLE mig.StgTelefono;
IF OBJECT_ID('mig.StgCuenta')      IS NOT NULL DROP TABLE mig.StgCuenta;

CREATE TABLE mig.StgCuenta (
    IdControl int NOT NULL, Numero varchar(50) NULL, Cliente varchar(200) NULL,
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

-- Algunas carteras (MBA) tienen NECU_NOMBRE_CLIENTE varchar(200) y NECU_CUENTA
-- varchar(50). El staging se crea con esos anchos para que SqlBulkCopy no falle
-- con "invalid column length from the bcp client". Las columnas destino de
-- demográficos también se ensanchan a 200 (no tienen índices sobre ellas).
ALTER TABLE ope.Demografico ALTER COLUMN Colonia varchar(200) NULL;
ALTER TABLE ope.Demografico ALTER COLUMN Delegacion varchar(200) NULL;
ALTER TABLE ope.Demografico ALTER COLUMN Estado varchar(200) NULL;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Telefono_RegistroLegacy' AND object_id=OBJECT_ID('ope.Telefono'))
    CREATE INDEX IX_Telefono_RegistroLegacy ON ope.Telefono(IdRegistroLegacy);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Gestion_RegistroLegacy' AND object_id=OBJECT_ID('ope.Gestion'))
    CREATE INDEX IX_Gestion_RegistroLegacy ON ope.Gestion(IdRegistroLegacy);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Promesa_RegistroLegacy' AND object_id=OBJECT_ID('ope.Promesa'))
    CREATE INDEX IX_Promesa_RegistroLegacy ON ope.Promesa(IdRegistroLegacy);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Demografico_RegistroLegacy' AND object_id=OBJECT_ID('ope.Demografico'))
    CREATE INDEX IX_Demografico_RegistroLegacy ON ope.Demografico(IdRegistroLegacy);

DELETE d FROM ope.Demografico d JOIN ope.Cuenta c ON c.IdCuenta=d.IdCuenta WHERE c.IdControlLegacy>0;
DELETE p FROM ope.Promesa p JOIN ope.Cuenta c ON c.IdCuenta=p.IdCuenta WHERE c.IdControlLegacy>0;
DELETE g FROM ope.Gestion g JOIN ope.Cuenta c ON c.IdCuenta=g.IdCuenta WHERE c.IdControlLegacy>0;
DELETE t FROM ope.Telefono t JOIN ope.Cuenta c ON c.IdCuenta=t.IdCuenta WHERE c.IdControlLegacy>0;
DELETE FROM ope.Cuenta WHERE IdControlLegacy>0;
'@

$carteras = Invoke-Sql -Cadena $cadenaLocal -Tabla -Sql @'
SET NOCOUNT ON;
SELECT IdCartera, Nombre FROM cart.Cartera WHERE Activo=1 ORDER BY IdCartera;
'@
Escribe "Carteras a migrar: $($carteras.Rows.Count)"

# ---------------------------------------------------------------------------
# 2. Definición de entidades (origen remoto -> staging -> tabla destino).
# ---------------------------------------------------------------------------
$entidades = @(
    @{
        Nombre='Cuenta'; Origen='NECU_DATOSCUENTA'; Clave='NECU_ID_CONTROL'; Staging='mig.StgCuenta';
        Columnas=@('IdControl','Numero','Cliente','Situacion','Saldo','IdEmpleado','GestionDesc','FechaCarga');
        Select='SELECT TOP (LOTE) NECU_ID_CONTROL AS IdControl, NECU_CUENTA AS Numero, NECU_NOMBRE_CLIENTE AS Cliente, NECU_ID_SITUACION_CUENTA AS Situacion, SALDO_EXPR AS Saldo, NECU_ID_EMPLEADO AS IdEmpleado, GESTION_EXPR AS GestionDesc, NECU_FECHA_CARGA AS FechaCarga FROM NECU_DATOSCUENTA WHERE NECU_ID_CONTROL > ULTIMO ORDER BY NECU_ID_CONTROL';
        Destino=@'
INSERT INTO ope.Cuenta (IdCartera, IdControlLegacy, NumeroCuenta, NombreCliente, SituacionCuenta, RazonMora, Saldo, IdEmpleado, FechaRegistro)
SELECT CARTERA, s.IdControl,
       ISNULL(NULLIF(LTRIM(RTRIM(s.Numero)),''), CONCAT('C', s.IdControl)),
       NULLIF(LTRIM(RTRIM(s.Cliente)),''),
       CONCAT('Situacion legacy ', ISNULL(s.Situacion,0)),
       LEFT(NULLIF(LTRIM(RTRIM(s.GestionDesc)),''),100), s.Saldo,
       ISNULL(e.IdEmpleado,6), ISNULL(s.FechaCarga, SYSDATETIME())
FROM mig.StgCuenta s LEFT JOIN rh.Empleado e ON e.IdEmpleado=s.IdEmpleado
WHERE NOT EXISTS (SELECT 1 FROM ope.Cuenta x WHERE x.IdCartera=CARTERA AND x.IdControlLegacy=s.IdControl);
'@
    },
    @{
        Nombre='Telefono'; Origen='NEBT_BASE_TELEFONICA'; Clave='NEBT_ID_BASE_TEL'; Staging='mig.StgTelefono';
        Columnas=@('IdBaseTel','IdControl','Numero','Tipo','Lada','Prefijo','Activo');
        Select='SELECT TOP (LOTE) NEBT_ID_BASE_TEL AS IdBaseTel, NEBT_ID_CONTROL AS IdControl, NEBT_TELEFONO AS Numero, NEBT_TIPO_TEL AS Tipo, NEBT_LADA AS Lada, NEBT_PREFIJO AS Prefijo, NEBT_ACTIVO AS Activo FROM NEBT_BASE_TELEFONICA WHERE NEBT_ID_BASE_TEL > ULTIMO ORDER BY NEBT_ID_BASE_TEL';
        Destino=@'
INSERT INTO ope.Telefono (IdCuenta, IdCartera, Numero, Tipo, Origen, IdRegistroLegacy, Activo)
SELECT c.IdCuenta, CARTERA,
       ISNULL(NULLIF(LTRIM(RTRIM(s.Numero)),''), CONCAT('S', s.IdBaseTel)),
       NULLIF(LTRIM(RTRIM(s.Tipo)),''),
       CONCAT('Lada ', ISNULL(s.Lada,0), ' / Prefijo ', ISNULL(s.Prefijo,0)),
       s.IdBaseTel, ISNULL(s.Activo,1)
FROM mig.StgTelefono s JOIN ope.Cuenta c ON c.IdCartera=CARTERA AND c.IdControlLegacy=s.IdControl
WHERE NOT EXISTS (SELECT 1 FROM ope.Telefono t WHERE t.IdCartera=CARTERA AND t.IdRegistroLegacy=s.IdBaseTel);
'@
    },
    @{
        Nombre='Gestion'; Origen='NEGE_GESTION'; Clave='NEGE_ID_GESTION'; Staging='mig.StgGestion';
        Columnas=@('IdGestion','IdControl','IdEmpleado','IdStatus','IdIntegracion','FechaGestion','HoraInicio','HoraFin','TelefonoMarcado','Comentario','TiempoLlamada','TiempoEscritura','Inbound');
        Select='SELECT TOP (LOTE) NEGE_ID_GESTION AS IdGestion, NEGE_ID_CONTROL AS IdControl, NEGE_ID_EMPLEADO AS IdEmpleado, NEGE_ID_STATUS AS IdStatus, NEGE_ID_INTEGRACION AS IdIntegracion, NEGE_FECHA_GESTION AS FechaGestion, NEGE_HORA_INICIO_GESTION AS HoraInicio, NEGE_HORA_FIN_GESTION AS HoraFin, NEGE_TELEFONO_MARCADO AS TelefonoMarcado, NEGE_COMENTARIO AS Comentario, NEGE_TIEMPO_LLAMADA AS TiempoLlamada, NEGE_TIEMPO_ESCRITURA AS TiempoEscritura, NEGE_INBOUND AS Inbound FROM NEGE_GESTION WHERE NEGE_ID_GESTION > ULTIMO ORDER BY NEGE_ID_GESTION';
        Destino=@'
INSERT INTO ope.Gestion (IdCuenta, IdCartera, IdEmpleado, IdTipoGestion, TelefonoMarcado, Comentario, Inbound, FechaInicio, FechaFin, TiempoLlamadaSegundos, TiempoEscrituraSegundos, IdIntegracionLegacy, IdRegistroLegacy)
SELECT c.IdCuenta, CARTERA, ISNULL(e.IdEmpleado,6), 1,
       NULLIF(LTRIM(RTRIM(s.TelefonoMarcado)),''),
       CONCAT('[Status legacy ', ISNULL(s.IdStatus,0), '] ', ISNULL(s.Comentario,'')),
       ISNULL(s.Inbound,0), ISNULL(s.HoraInicio, CAST(s.FechaGestion AS datetime2(0))), s.HoraFin,
       s.TiempoLlamada, s.TiempoEscritura, s.IdIntegracion, s.IdGestion
FROM mig.StgGestion s
JOIN ope.Cuenta c ON c.IdCartera=CARTERA AND c.IdControlLegacy=s.IdControl
LEFT JOIN rh.Empleado e ON e.IdEmpleado=s.IdEmpleado
WHERE NOT EXISTS (SELECT 1 FROM ope.Gestion g WHERE g.IdCartera=CARTERA AND g.IdRegistroLegacy=s.IdGestion);
'@
    },
    @{
        Nombre='Promesa'; Origen='NEPR_PROMESAS'; Clave='NEPR_ID_PROMESA'; Staging='mig.StgPromesa';
        Columnas=@('IdPromesa','IdControl','IdGestion','FechaPromesa','Monto','Lugar','Activo');
        Select='SELECT TOP (LOTE) NEPR_ID_PROMESA AS IdPromesa, NEPR_ID_CONTROL AS IdControl, NEPR_ID_GESTION AS IdGestion, NEPR_FECHA_PROMESA_PAGO AS FechaPromesa, NEPR_MONTO_PROMESA_PAGO AS Monto, NEPR_LUGAR AS Lugar, NEPR_ACTIVO AS Activo FROM NEPR_PROMESAS WHERE NEPR_ID_PROMESA > ULTIMO ORDER BY NEPR_ID_PROMESA';
        Destino=@'
INSERT INTO ope.Promesa (IdCuenta, IdCartera, Monto, FechaPromesa, LugarPago, Estatus, IdRegistroLegacy)
SELECT c.IdCuenta, CARTERA, ISNULL(s.Monto,0), CAST(ISNULL(s.FechaPromesa,GETDATE()) AS date),
       NULLIF(LTRIM(RTRIM(s.Lugar)),''),
       CASE WHEN ISNULL(s.Activo,1)=1 THEN 'PENDIENTE' ELSE 'CANCELADA' END, s.IdPromesa
FROM mig.StgPromesa s JOIN ope.Cuenta c ON c.IdCartera=CARTERA AND c.IdControlLegacy=s.IdControl
WHERE NOT EXISTS (SELECT 1 FROM ope.Promesa p WHERE p.IdCartera=CARTERA AND p.IdRegistroLegacy=s.IdPromesa);
'@
    },
    @{
        Nombre='Demografico'; Origen='NEDE_DEMOGRAFICOS'; Clave='NEDE_ID_DEMOGRAFICO'; Staging='mig.StgDemografico';
        Columnas=@('IdDemo','IdControl','Calle','Colonia','CP','ColoniaMunicipio','Municipio','Activo');
        Select='SELECT TOP (LOTE) NEDE_ID_DEMOGRAFICO AS IdDemo, NEDE_ID_CONTROL AS IdControl, NEDE_CALLE AS Calle, NEDE_COLONIA AS Colonia, NEDE_CP AS CP, NEDE_DEL_MUN AS ColoniaMunicipio, NEDE_MUNICIPIO AS Municipio, NEDE_ACTIVO AS Activo FROM NEDE_DEMOGRAFICOS WHERE NEDE_ID_DEMOGRAFICO > ULTIMO ORDER BY NEDE_ID_DEMOGRAFICO';
        Destino=@'
INSERT INTO ope.Demografico (IdCuenta, IdCartera, Calle, Colonia, CodigoPostal, Delegacion, Estado, IdRegistroLegacy)
SELECT c.IdCuenta, CARTERA, NULLIF(LTRIM(RTRIM(s.Calle)),''), NULLIF(LTRIM(RTRIM(s.Colonia)),''),
       NULLIF(LTRIM(RTRIM(s.CP)),''), NULLIF(LTRIM(RTRIM(s.ColoniaMunicipio)),''),
       NULLIF(LTRIM(RTRIM(s.Municipio)),''), s.IdDemo
FROM mig.StgDemografico s JOIN ope.Cuenta c ON c.IdCartera=CARTERA AND c.IdControlLegacy=s.IdControl
WHERE NOT EXISTS (SELECT 1 FROM ope.Demografico d WHERE d.IdCartera=CARTERA AND d.IdRegistroLegacy=s.IdDemo);
'@
    }
)

# ---------------------------------------------------------------------------
# 3. Migración por cartera y entidad, por lotes.
# ---------------------------------------------------------------------------
foreach ($filaCartera in $carteras.Rows) {
    $idCartera = [int]$filaCartera['IdCartera']
    $baseRemota = [string]$filaCartera['Nombre']
    $cnRemota = Cadena-Remota -Base $baseRemota
    Escribe "=== Cartera $idCartera : $baseRemota ==="
    $columnasRemotas = ObtenerColumnasRemotas -Cadena $cnRemota

    foreach ($entidad in $entidades) {
        $sqlOrigenBase = $entidad.Select
        if ($entidad.Nombre -eq 'Cuenta') {
            $saldoExpr = ExpresionSaldo -Columnas $columnasRemotas
            $gestionExpr = ExpresionGestion -Columnas $columnasRemotas
            $sqlOrigenBase = $sqlOrigenBase.Replace('SALDO_EXPR', $saldoExpr).Replace('GESTION_EXPR', $gestionExpr)
        }
        $ultimo = [long]0
        $leidas = [long]0
        $idCarga = (Invoke-Sql -Cadena $cadenaLocal -Tabla -Sql @"
EXEC mig.USP_INICIA_CARGA @NombreCarga='$nombreCarga', @OrigenServidor='$hostRemoto',
     @OrigenBase='$baseRemota', @Entidad='$($entidad.Nombre)', @Usuario='MIGRACION', @FilasLeidas=0;
"@).Rows[0][0]

        $sqlDestino = $entidad.Destino.Replace('CARTERA', [string]$idCartera)
        do {
            $sqlOrigen = $sqlOrigenBase.Replace('LOTE', [string]$lote).Replace('ULTIMO', [string]$ultimo)
            $datos = Invoke-Sql -Cadena $cnRemota -Sql $sqlOrigen -Tabla
            $cantidad = $datos.Rows.Count
            if ($cantidad -eq 0) { break }

            Invoke-Sql -Cadena $cadenaLocal -Sql "TRUNCATE TABLE $($entidad.Staging);"
            $bulk = New-Object System.Data.SqlClient.SqlBulkCopy($cadenaLocal)
            $bulk.DestinationTableName = $entidad.Staging
            $bulk.BatchSize = $lote
            $bulk.BulkCopyTimeout = 1200
            foreach ($col in $entidad.Columnas) { [void]$bulk.ColumnMappings.Add($col, $col) }
            [void]$bulk.WriteToServer($datos)
            $bulk.Dispose()

            Invoke-Sql -Cadena $cadenaLocal -Sql $sqlDestino
            $ultimo = [long]$datos.Rows[$cantidad - 1][0]
            $leidas += $cantidad
            Escribe "  $($entidad.Nombre): $leidas filas acumuladas (lote de $cantidad)"
        } while ($cantidad -eq $lote)

        Invoke-Sql -Cadena $cadenaLocal -Sql @"
EXEC mig.USP_FINALIZA_CARGA @IdCarga=$idCarga, @FilasInsertadas=$leidas, @UltimoIdLegacy=$ultimo,
     @Detalle='Cartera $idCartera ($baseRemota); clave $($entidad.Clave)';
"@
    }
}

# ---------------------------------------------------------------------------
# 4. Verificación final.
# ---------------------------------------------------------------------------
Escribe ''
Escribe '--- Conteos finales en BABEL_UNIFICADA ---'
$ver = Invoke-Sql -Cadena $cadenaLocal -Tabla -Sql @'
SET NOCOUNT ON;
SELECT 'ope.Cuenta' Entidad, COUNT(*) Filas FROM ope.Cuenta
UNION ALL SELECT 'ope.Telefono', COUNT(*) FROM ope.Telefono
UNION ALL SELECT 'ope.Gestion', COUNT(*) FROM ope.Gestion
UNION ALL SELECT 'ope.Promesa', COUNT(*) FROM ope.Promesa
UNION ALL SELECT 'ope.Demografico', COUNT(*) FROM ope.Demografico;
SELECT Estatus, COUNT(*) Cargas FROM mig.ControlCarga WHERE NombreCarga='OPERATIVO_COMPLETO_13_CARTERAS' GROUP BY Estatus;
'@
$ver | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
Escribe 'Migración completa terminada.'
