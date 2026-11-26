<#
  BABEL_UNIFICADA - Migración total - 02. Copia masiva de todas las tablas.
  Lee SOLO con SELECT desde 10.80.5.189 y escribe en localhost/BABEL_UNIFICADA.
  Usa SqlBulkCopy.WriteToServer(IDataReader) para streaming (bajo consumo de memoria).
  Reanudable: si la tabla/cartera ya tiene el conteo esperado, se omite.

  REGLA: nunca INSERT/UPDATE/DELETE/BACKUP en el remoto. Nunca imprimir contraseña.
#>
$ErrorActionPreference = 'Stop'

$configXml = 'C:\Users\sbasilio\Desktop\Trabajos\ingenieria inversa\APLICATIVOS\analysis\BABELGESTION.xml'
$carpeta = Join-Path $PSScriptRoot 'inventario'
$cadenaLocal = 'Server=localhost;Database=BABEL_UNIFICADA;Integrated Security=True;TrustServerCertificate=True;Encrypt=False;'

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
        $cmd.CommandTimeout = 0
        if ($Tabla) {
            $da = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
            $dt = New-Object System.Data.DataTable
            [void]$da.Fill($dt)
            Write-Output -NoEnumerate $dt
            return
        }
        [void]$cmd.ExecuteNonQuery()
    }
    finally { $cn.Dispose() }
}

function Cadena-Remota([string]$Base) {
    return "Server=$hostRemoto,$puertoRemoto;User ID=$usuarioRemoto;Password=$passwordRemoto;Database=$Base;TrustServerCertificate=True;Encrypt=False;Connect Timeout=15;"
}

function Escribe([string]$Texto) {
    Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Texto)
}

function Esc-Sql([string]$s) { return $s.Replace("'", "''") }

$carteras = Invoke-Sql -Cadena $cadenaLocal -Tabla -Sql "SET NOCOUNT ON; SELECT IdCartera, Nombre FROM cart.Cartera WHERE Activo=1 ORDER BY IdCartera;"
$tablasInv = Import-Csv (Join-Path $carpeta 'tablas.csv')
$colsInv = Import-Csv (Join-Path $carpeta 'columnas.csv')
$resumenCols = Import-Csv (Join-Path $carpeta 'resumen_columnas.csv')

# Solo tablas con filas en algún remoto
$tablasConDatos = $tablasInv | Where-Object { [long]$_.Filas -gt 0 } |
    Group-Object Tabla | ForEach-Object { $_.Name } | Sort-Object

Escribe "Tablas con datos: $($tablasConDatos.Count)"
Escribe "Carteras: $($carteras.Rows.Count)"

$totalCopiadas = 0
$totalOmitidas = 0
$errores = New-Object System.Collections.Generic.List[string]

foreach ($filaCartera in $carteras.Rows) {
    $idCartera = [int]$filaCartera['IdCartera']
    $base = [string]$filaCartera['Nombre']
    $cnRemota = Cadena-Remota $base
    Escribe "=== Cartera $idCartera : $base ==="

    foreach ($tabla in $tablasConDatos) {
        $inv = $tablasInv | Where-Object { [int]$_.IdCartera -eq $idCartera -and $_.Tabla -eq $tabla } | Select-Object -First 1
        if (-not $inv) { continue }
        $filasEsperadas = [long]$inv.Filas
        if ($filasEsperadas -le 0) { continue }

        # Conteo local para reanudación
        $local = (Invoke-Sql -Cadena $cadenaLocal -Tabla -Sql "SET NOCOUNT ON; SELECT COUNT_BIG(*) C FROM legacy.[$tabla] WHERE __IdCartera=$idCartera;").Rows[0]['C']
        $filasLocales = [long]$local
        if ($filasLocales -ge $filasEsperadas) {
            Escribe "  SKIP $tabla ($filasLocales/$filasEsperadas)"
            $totalOmitidas++
            continue
        }
        if ($filasLocales -gt 0 -and $filasLocales -lt $filasEsperadas) {
            Escribe "  REINICIO $tabla local=$filasLocales esperado=$filasEsperadas (limpiando cartera)"
            Invoke-Sql -Cadena $cadenaLocal -Sql "DELETE FROM legacy.[$tabla] WHERE __IdCartera=$idCartera;"
        }

        $cols = @($colsInv | Where-Object { [int]$_.IdCartera -eq $idCartera -and $_.Tabla -eq $tabla } | Sort-Object { [int]$_.Orden })
        if ($cols.Count -eq 0) { continue }
        $colNames = @($cols | ForEach-Object { [string]$_.Columna })
        $tiposTexto = @('char','nchar','varchar','nvarchar','text','ntext','sysname','xml','uniqueidentifier')
        $selectExprs = @()
        foreach ($c in $cols) {
            $n = [string]$c.Columna
            $t = ([string]$c.Tipo).ToLowerInvariant().Trim()
            $sup = $resumenCols | Where-Object { $_.Tabla -eq $tabla -and $_.Columna -eq $n } | Select-Object -First 1
            $supTipos = @()
            if ($sup) { $supTipos = @(([string]$sup.Tipos) -split '\|' | ForEach-Object { $_.ToLowerInvariant().Trim() }) }
            $mirrorEsTexto = ($supTipos | Where-Object { $tiposTexto -contains $_ }).Count -gt 0
            if ($mirrorEsTexto -or ($tiposTexto -contains $t)) {
                $selectExprs += "CAST([$n] AS nvarchar(max)) COLLATE Modern_Spanish_CI_AS AS [$n]"
            } else {
                $selectExprs += "[$n]"
            }
        }
        $selectCols = ($selectExprs -join ', ')
        $sqlOrigen = "SELECT CAST($idCartera AS tinyint) AS __IdCartera, CAST(N'$(Esc-Sql $base)' AS nvarchar(50)) COLLATE Modern_Spanish_CI_AS AS __BaseOrigen, $selectCols FROM dbo.[$tabla] WITH (NOLOCK);"

        $cnR = New-Object System.Data.SqlClient.SqlConnection($cnRemota)
        $cnL = New-Object System.Data.SqlClient.SqlConnection($cadenaLocal)
        try {
            $cnR.Open()
            $cnL.Open()
            $cmd = $cnR.CreateCommand()
            $cmd.CommandText = $sqlOrigen
            $cmd.CommandTimeout = 0
            $reader = $cmd.ExecuteReader()

            $bulk = New-Object System.Data.SqlClient.SqlBulkCopy($cnL)
            $bulk.DestinationTableName = "legacy.[$tabla]"
            $bulk.BulkCopyTimeout = 0
            $bulk.BatchSize = 50000
            $bulk.EnableStreaming = $true
            [void]$bulk.ColumnMappings.Add('__IdCartera', '__IdCartera')
            [void]$bulk.ColumnMappings.Add('__BaseOrigen', '__BaseOrigen')
            foreach ($c in $colNames) { [void]$bulk.ColumnMappings.Add($c, $c) }

            $t0 = Get-Date
            $bulk.WriteToServer($reader)
            $reader.Close()
            $bulk.Close()
            $seg = [int]((Get-Date) - $t0).TotalSeconds
            $totalCopiadas++
            Escribe "  OK $tabla : $filasEsperadas filas ($seg s)"
        }
        catch {
            $msg = "ERR cartera=$idCartera tabla=$tabla : $($_.Exception.Message)"
            Escribe "  $msg"
            $errores.Add($msg)
            try { if ($reader -and -not $reader.IsClosed) { $reader.Close() } } catch {}
            try { if ($bulk) { $bulk.Close() } } catch {}
        }
        finally {
            $cnR.Dispose()
            $cnL.Dispose()
        }
    }
}

Escribe ''
Escribe "=== RESUMEN ==="
Escribe "Tablas/cartera copiadas: $totalCopiadas"
Escribe "Tablas/cartera omitidas (ya completas): $totalOmitidas"
Escribe "Errores: $($errores.Count)"
if ($errores.Count -gt 0) {
    $errores | ForEach-Object { Escribe "  $_" }
    $logErr = Join-Path $PSScriptRoot 'errores_migracion.log'
    $errores | Set-Content -Path $logErr -Encoding UTF8
    Escribe "Log errores: $logErr"
}
