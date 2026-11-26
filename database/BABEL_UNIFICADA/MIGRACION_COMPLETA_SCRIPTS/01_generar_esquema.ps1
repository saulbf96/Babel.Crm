<#
  Genera 01_esquema_legacy.sql desde inventario/resumen_*.csv.
  Crea el esquema legacy con un espejo ancho por tabla remota.
  No se conecta al remoto. Solo lee CSV locales.
#>
$ErrorActionPreference = 'Stop'
$carpeta = Join-Path $PSScriptRoot 'inventario'
$salida = Join-Path $PSScriptRoot '01_esquema_legacy.sql'

$tablas = Import-Csv (Join-Path $carpeta 'resumen_tablas.csv')
$columnas = Import-Csv (Join-Path $carpeta 'resumen_columnas.csv')
$claves = Import-Csv (Join-Path $carpeta 'claves.csv')

function Get-TipoSql([object]$c, [bool]$esClave) {
    $tipos = @(([string]$c.Tipos) -split '\|' | ForEach-Object { $_.ToLowerInvariant().Trim() } | Where-Object { $_ })
    $maxLen = [int]$c.MaxLength
    $precision = [int]$c.Precision
    $scale = [int]$c.Scale

    $esTexto = $tipos | Where-Object { $_ -in @('char','nchar','varchar','nvarchar','text','ntext','sysname','xml','uniqueidentifier') }
    $esBin = $tipos | Where-Object { $_ -in @('binary','varbinary','image','timestamp','rowversion') }
    $esTiempo = $tipos | Where-Object { $_ -eq 'time' }
    $esFecha = $tipos | Where-Object { $_ -in @('date','datetime','datetime2','smalldatetime','datetimeoffset') }
    $esDecimal = $tipos | Where-Object { $_ -in @('decimal','numeric','money','smallmoney') }
    $esFloat = $tipos | Where-Object { $_ -in @('float','real') }
    $esInt = $tipos | Where-Object { $_ -in @('bigint','int','smallint','tinyint','bit') }

    if ($esTexto) {
        if ($esClave) { return 'nvarchar(450)' }
        # MaxLength en sys.columns: -1=max; para n* es bytes (2*chars).
        if ($maxLen -eq -1) { return 'nvarchar(max)' }
        $esN = $tipos | Where-Object { $_ -in @('nchar','nvarchar','ntext','sysname','xml') }
        $chars = if ($esN) { [Math]::Ceiling($maxLen / 2.0) } else { $maxLen }
        if ($chars -le 0 -or $chars -gt 4000) { return 'nvarchar(max)' }
        return "nvarchar($chars)"
    }
    if ($esBin) { return $(if ($esClave) { 'varbinary(900)' } else { 'varbinary(max)' }) }
    if ($esTiempo -and -not $esFecha) { return 'time(7)' }
    if ($esFecha -or $esTiempo) { return 'datetime2(7)' }
    if ($esDecimal) {
        if ($tipos -contains 'money') { return 'decimal(19,4)' }
        if ($tipos -contains 'smallmoney') { return 'decimal(10,4)' }
        $p = if ($precision -gt 0) { [Math]::Min($precision, 38) } else { 38 }
        $s = if ($scale -ge 0) { [Math]::Min($scale, $p) } else { 0 }
        return "decimal($p,$s)"
    }
    if ($esFloat) { return 'float' }
    if ($esInt) {
        if ($tipos -contains 'bigint') { return 'bigint' }
        if ($tipos -contains 'int') { return 'bigint' } # ancho seguro
        if ($tipos -contains 'smallint') { return 'int' }
        if ($tipos -contains 'tinyint') { return 'int' }
        if ($tipos -contains 'bit') { return 'bit' }
        return 'bigint'
    }
    return $(if ($esClave) { 'nvarchar(450)' } else { 'nvarchar(max)' })
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("/* Generado por 01_generar_esquema.ps1 - espejo legacy completo */")
[void]$sb.AppendLine("SET NOCOUNT ON;")
[void]$sb.AppendLine("SET XACT_ABORT ON;")
[void]$sb.AppendLine("GO")
[void]$sb.AppendLine("IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'legacy')")
[void]$sb.AppendLine("    EXEC('CREATE SCHEMA legacy');")
[void]$sb.AppendLine("GO")
[void]$sb.AppendLine("")

foreach ($t in ($tablas | Sort-Object Tabla)) {
    $tabla = [string]$t.Tabla
    $cols = $columnas | Where-Object { $_.Tabla -eq $tabla } | Sort-Object { [int]$_.Orden }, Columna
    $pk = @($claves | Where-Object { $_.Tabla -eq $tabla } | Sort-Object { [int]$_.Orden } | ForEach-Object { [string]$_.Columna } | Select-Object -Unique)

    [void]$sb.AppendLine("IF OBJECT_ID('legacy.$tabla', 'U') IS NOT NULL DROP TABLE legacy.$tabla;")
    [void]$sb.AppendLine("GO")
    [void]$sb.AppendLine("CREATE TABLE legacy.$tabla (")
    [void]$sb.AppendLine("    __IdCartera tinyint NOT NULL,")
    [void]$sb.AppendLine("    __BaseOrigen nvarchar(50) NOT NULL,")
    [void]$sb.AppendLine("    __FechaMigracion datetime2(0) NOT NULL DEFAULT SYSDATETIME(),")

    $defs = @()
    foreach ($c in $cols) {
        $nombre = [string]$c.Columna
        $esClave = $pk -contains $nombre
        $tipo = Get-TipoSql $c $esClave
        $nullable = 'NULL' # espejo tolerante
        $defs += "    [$nombre] $tipo $nullable"
    }
    [void]$sb.AppendLine(($defs -join ",`r`n"))
    [void]$sb.AppendLine(");")
    [void]$sb.AppendLine("GO")
    [void]$sb.AppendLine("CREATE INDEX IX_L_${tabla}_Cartera ON legacy.$tabla(__IdCartera);")
    if ($pk.Count -gt 0) {
        $pkCols = ($pk | ForEach-Object { "[$_]" }) -join ', '
        [void]$sb.AppendLine("CREATE INDEX IX_L_${tabla}_PK ON legacy.$tabla(__IdCartera, $pkCols);")
    }
    [void]$sb.AppendLine("GO")
    [void]$sb.AppendLine("")
}

[System.IO.File]::WriteAllText($salida, $sb.ToString(), [System.Text.Encoding]::UTF8)
Write-Host "Generado: $salida"
Write-Host "Tablas: $($tablas.Count)"