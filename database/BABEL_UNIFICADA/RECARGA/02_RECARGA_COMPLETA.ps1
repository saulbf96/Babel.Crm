<#
  BABEL_UNIFICADA - RECARGA / 02. Todo en uno: TRUNCATE + migración + verificación.

  Uso:
    powershell -NoProfile -ExecutionPolicy Bypass -File database\BABEL_UNIFICADA\RECARGA\02_RECARGA_COMPLETA.ps1
    powershell -NoProfile -ExecutionPolicy Bypass -File database\BABEL_UNIFICADA\RECARGA\02_RECARGA_COMPLETA.ps1 -ConBackup

  El backup, si se pide, es LOCAL (localhost). No se inicia ni se detiene ningún
  servidor. En 10.80.5.189 la migración solo ejecuta SELECT; la contraseña del
  XML nunca se imprime.

  Log: %TEMP%\opencode\recarga_completa_yyyyMMdd_HHmmss.log
#>
param([switch]$ConBackup)

$ErrorActionPreference = 'Stop'

$carpeta = $PSScriptRoot
$raiz = Split-Path -Parent $carpeta
$backup   = Join-Path $carpeta '00_BACKUP_LOCAL.sql'
$truncate = Join-Path $carpeta '01_TRUNCATE_OPERATIVO.sql'
$verificar = Join-Path $carpeta '03_VERIFICAR_RECARGA.sql'
$migracion = Join-Path $raiz '11_mig_operativo_completo.ps1'

foreach ($archivo in @($truncate, $verificar, $migracion)) {
    if (-not (Test-Path $archivo)) { throw "No se encontró: $archivo" }
}

$dirLog = Join-Path $env:TEMP 'opencode'
if (-not (Test-Path $dirLog)) { New-Item -ItemType Directory -Path $dirLog | Out-Null }
$log = Join-Path $dirLog ('recarga_completa_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.log')

if ($ConBackup) {
    Write-Host '[RECARGA] Backup local previo...'
    & sqlcmd -S localhost -E -C -d master -b -i $backup
    if ($LASTEXITCODE -ne 0) { throw "Backup falló (exit $LASTEXITCODE). No se truncó nada." }
}

Write-Host '[RECARGA] TRUNCATE operativo...'
& sqlcmd -S localhost -E -C -d BABEL_UNIFICADA -b -i $truncate
if ($LASTEXITCODE -ne 0) { throw "TRUNCATE falló (exit $LASTEXITCODE). No se ejecutó la migración." }

Write-Host "[RECARGA] Migración completa (log: $log)"
& powershell -NoProfile -ExecutionPolicy Bypass -File $migracion 2>&1 | Tee-Object -FilePath $log
$codigo = $LASTEXITCODE
if ($codigo -ne 0) { throw "Migración falló (exit $codigo). Revisa $log" }

Write-Host '[RECARGA] Verificación final...'
& sqlcmd -S localhost -E -C -d BABEL_UNIFICADA -b -i $verificar
if ($LASTEXITCODE -ne 0) { throw "Verificación falló (exit $LASTEXITCODE)" }

Write-Host "[RECARGA] Terminada correctamente. Log: $log"
