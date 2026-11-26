<#
  BABEL_UNIFICADA - Migración total - 00. Inventario remoto (SOLO LECTURA).

  Lee las 13 bases de cartera de 10.80.5.189 y escribe CSV en .\inventario\:
    - tablas.csv          : una fila por tabla y cartera, con conteo de filas.
    - columnas.csv        : una fila por columna y cartera.
    - claves.csv          : columnas de la llave primaria.
    - modulos.csv         : SPs, funciones, vistas y triggers.
    - resumen_tablas.csv  : agregado por tabla (bases, filas, columnas).
    - resumen_columnas.csv: superset de columnas por tabla para generar el espejo.

  REGLA: aquí SOLO se ejecutan SELECT. La contraseña se lee del XML y nunca se
  imprime ni se escribe en los CSV/logs.
#>
$ErrorActionPreference = 'Stop'

$configXml = 'C:\Users\sbasilio\Desktop\Trabajos\ingenieria inversa\APLICATIVOS\analysis\BABELGESTION.xml'
$carpeta = Join-Path $PSScriptRoot 'inventario'
$cadenaLocal = 'Server=localhost;Database=BABEL_UNIFICADA;Integrated Security=True;TrustServerCertificate=True;Encrypt=False;'

if (-not (Test-Path $carpeta)) { New-Item -ItemType Directory -Path $carpeta | Out-Null }

[xml]$config = Get-Content -Path $configXml -Encoding UTF8
$hostRemoto = $config.SelectSingleNode('/BBDD/Server/Host').InnerText
$puertoRemoto = $config.SelectSingleNode('/BBDD/Server/Port').InnerText
$usuarioRemoto = $config.SelectSingleNode('/BBDD/Server/Usuario').InnerText
$passwordRemoto = $config.SelectSingleNode('/BBDD/Server/Password').InnerText

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

function Cadena-Remota {
    param([string]$Base)
    return "Server=$hostRemoto,$puertoRemoto;User ID=$usuarioRemoto;Password=$passwordRemoto;Database=$Base;TrustServerCertificate=True;Encrypt=False;Connect Timeout=15;"
}

function Escribe {
    param([string]$Texto)
    Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Texto)
}

$carteras = Invoke-Sql -Cadena $cadenaLocal -Tabla -Sql @'
SET NOCOUNT ON;
SELECT IdCartera, Nombre FROM cart.Cartera WHERE Activo = 1 ORDER BY IdCartera;
'@
Escribe "Carteras activas: $($carteras.Rows.Count)"

$tablas = New-Object System.Collections.Generic.List[object]
$columnas = New-Object System.Collections.Generic.List[object]
$claves = New-Object System.Collections.Generic.List[object]
$modulos = New-Object System.Collections.Generic.List[object]

foreach ($fila in $carteras.Rows) {
    $idCartera = [int]$fila['IdCartera']
    $base = [string]$fila['Nombre']
    Escribe "Inventariando cartera $idCartera : $base"
    $cn = Cadena-Remota -Base $base

    $dtTablas = Invoke-Sql -Cadena $cn -Tabla -Sql @'
SET NOCOUNT ON;
SELECT t.name AS Tabla,
       SUM(CASE WHEN p.index_id IN (0,1) THEN p.rows ELSE 0 END) AS Filas
FROM sys.tables t
LEFT JOIN sys.partitions p ON p.object_id = t.object_id
WHERE t.is_ms_shipped = 0
GROUP BY t.name
ORDER BY t.name;
'@
    foreach ($r in $dtTablas.Rows) {
        $tablas.Add([pscustomobject]@{
            IdCartera = $idCartera
            Base = $base
            Tabla = [string]$r['Tabla']
            Filas = [long]$r['Filas']
        })
    }

    $dtColumnas = Invoke-Sql -Cadena $cn -Tabla -Sql @'
SET NOCOUNT ON;
SELECT t.name AS Tabla,
       c.column_id AS Orden,
       c.name AS Columna,
       ty.name AS Tipo,
       c.max_length AS MaxLength,
       c.precision AS Precision,
       c.scale AS Scale,
       c.is_nullable AS EsNullable,
       COLUMNPROPERTY(c.object_id, c.name, 'IsIdentity') AS EsIdentity
FROM sys.tables t
JOIN sys.columns c ON c.object_id = t.object_id
JOIN sys.types ty ON ty.user_type_id = c.user_type_id
WHERE t.is_ms_shipped = 0
ORDER BY t.name, c.column_id;
'@
    foreach ($r in $dtColumnas.Rows) {
        $columnas.Add([pscustomobject]@{
            IdCartera = $idCartera
            Base = $base
            Tabla = [string]$r['Tabla']
            Orden = [int]$r['Orden']
            Columna = [string]$r['Columna']
            Tipo = [string]$r['Tipo']
            MaxLength = [int]$r['MaxLength']
            Precision = [int]$r['Precision']
            Scale = [int]$r['Scale']
            EsNullable = [bool]$r['EsNullable']
            EsIdentity = [bool]$r['EsIdentity']
        })
    }

    $dtClaves = Invoke-Sql -Cadena $cn -Tabla -Sql @'
SET NOCOUNT ON;
SELECT t.name AS Tabla,
       c.name AS Columna,
       ic.key_ordinal AS Orden
FROM sys.tables t
JOIN sys.indexes i ON i.object_id = t.object_id AND i.is_primary_key = 1
JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
WHERE t.is_ms_shipped = 0
ORDER BY t.name, ic.key_ordinal;
'@
    foreach ($r in $dtClaves.Rows) {
        $claves.Add([pscustomobject]@{
            IdCartera = $idCartera
            Base = $base
            Tabla = [string]$r['Tabla']
            Columna = [string]$r['Columna']
            Orden = [int]$r['Orden']
        })
    }

    $dtModulos = Invoke-Sql -Cadena $cn -Tabla -Sql @'
SET NOCOUNT ON;
SELECT CASE o.type
           WHEN 'P' THEN 'PROCEDURE'
           WHEN 'FN' THEN 'FUNCTION'
           WHEN 'IF' THEN 'FUNCTION'
           WHEN 'TF' THEN 'FUNCTION'
           WHEN 'V' THEN 'VIEW'
           WHEN 'TR' THEN 'TRIGGER'
           ELSE o.type_desc END AS Tipo,
       o.name AS Nombre
FROM sys.objects o
WHERE o.is_ms_shipped = 0
  AND o.type IN ('P','FN','IF','TF','V','TR')
ORDER BY o.type, o.name;
'@
    foreach ($r in $dtModulos.Rows) {
        $modulos.Add([pscustomobject]@{
            IdCartera = $idCartera
            Base = $base
            Tipo = [string]$r['Tipo']
            Nombre = [string]$r['Nombre']
        })
    }
}

$tablas | Export-Csv -Path (Join-Path $carpeta 'tablas.csv') -NoTypeInformation -Encoding UTF8
$columnas | Export-Csv -Path (Join-Path $carpeta 'columnas.csv') -NoTypeInformation -Encoding UTF8
$claves | Export-Csv -Path (Join-Path $carpeta 'claves.csv') -NoTypeInformation -Encoding UTF8
$modulos | Export-Csv -Path (Join-Path $carpeta 'modulos.csv') -NoTypeInformation -Encoding UTF8

# Agregados para diseñar el espejo.
$resumenTablas = $tablas | Group-Object Tabla | ForEach-Object {
    $nombre = $_.Name
    [pscustomobject]@{
        Tabla = $nombre
        Bases = ($_.Group | Where-Object { $_.Filas -gt 0 }).Count
        FilasTotal = ($_.Group | Measure-Object Filas -Sum).Sum
        FilasMax = ($_.Group | Measure-Object Filas -Maximum).Maximum
        Columnas = ($columnas | Where-Object { $_.Tabla -eq $nombre }).Count
    }
} | Sort-Object FilasTotal -Descending

$resumenColumnas = $columnas | Group-Object Tabla, Columna | ForEach-Object {
    $primera = $_.Group[0]
    [pscustomobject]@{
        Tabla = $primera.Tabla
        Columna = $primera.Columna
        Orden = ($_.Group | Measure-Object Orden -Minimum).Minimum
        Tipos = (($_.Group | Select-Object -ExpandProperty Tipo -Unique) -join '|')
        MaxLength = ($_.Group | Measure-Object MaxLength -Maximum).Maximum
        Precision = ($_.Group | Measure-Object Precision -Maximum).Maximum
        Scale = ($_.Group | Measure-Object Scale -Maximum).Maximum
        EsNullable = ($_.Group | Where-Object { $_.EsNullable }).Count -gt 0
        EsIdentity = ($_.Group | Where-Object { $_.EsIdentity }).Count -gt 0
        Bases = $_.Group.Count
    }
} | Sort-Object Tabla, Orden

$resumenTablas | Export-Csv -Path (Join-Path $carpeta 'resumen_tablas.csv') -NoTypeInformation -Encoding UTF8
$resumenColumnas | Export-Csv -Path (Join-Path $carpeta 'resumen_columnas.csv') -NoTypeInformation -Encoding UTF8

Escribe ''
Escribe '--- Resumen por tabla (top 40 por filas) ---'
$resumenTablas | Select-Object -First 40 | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
Escribe ''
Escribe "Tablas distintas: $($resumenTablas.Count); columnas distintas: $($resumenColumnas.Count)"
Escribe "CSV generados en: $carpeta"
