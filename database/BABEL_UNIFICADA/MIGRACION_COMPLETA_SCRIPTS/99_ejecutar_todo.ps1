<#
  Orquestador opcional. Ejecuta migración completa.
  Respeta la regla: remoto 10.80.5.189 solo SELECT.
  18_seg_provisionar_usuarios.ps1 requiere -ContrasenaTemporal (paso manual).
#>
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
function Run-Step([string]$name, [scriptblock]$action) {
    Write-Host "==== $name ====" -ForegroundColor Cyan
    & $action
    if ($LASTEXITCODE -ne 0) { throw "Falló: $name (exit $LASTEXITCODE)" }
}

Run-Step '00 Inventario' { powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root '00_inventario_remoto.ps1') }
Run-Step '01 Generar esquema' { powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root '01_generar_esquema.ps1') }
Run-Step '01 Aplicar esquema' { sqlcmd -S localhost -E -C -d BABEL_UNIFICADA -b -i (Join-Path $root '01_esquema_legacy.sql') }
Run-Step '02 Copiar todo' { powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root '02_migrar_todo.ps1') }
Run-Step '06 Stubs históricos' { sqlcmd -S localhost -E -C -d BABEL_UNIFICADA -b -i (Join-Path $root '06_cuentas_stub_historicas.sql') }
Run-Step '03 Normalizar' { sqlcmd -S localhost -E -C -d BABEL_UNIFICADA -b -i (Join-Path $root '03_normalizar_operativo.sql') }
Run-Step '04 SPs legacy' { sqlcmd -S localhost -E -C -d BABEL_UNIFICADA -b -I -i (Join-Path $root '04_sps_legacy.sql') }
Run-Step '20 Unificar empleados' { sqlcmd -S localhost -E -C -d BABEL_UNIFICADA -b -v SIMULAR=0 -i (Join-Path $root '20_rh_unificar_empleados.sql') }
Write-Host 'Paso manual: ejecutar 18_seg_provisionar_usuarios.ps1 con -ContrasenaTemporal o -Simular.' -ForegroundColor Yellow
Run-Step '05 Verificar' { sqlcmd -S localhost -E -C -d BABEL_UNIFICADA -b -i (Join-Path $root '05_verificar.sql') }
Write-Host 'Migración total finalizada.' -ForegroundColor Green
