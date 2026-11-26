<#
  BABEL_UNIFICADA - 18. Crea usuarios del CRM para los empleados activos que no tienen.

  - Usuario = inicial del nombre + apellido paterno (sin acentos ni espacios, en MAYÚSCULAS).
    Ej. OMAR EMILIO RODRIGUEZ AVALOS -> ORODRIGUEZ. Si ya existe: ORODRIGUEZ2, ORODRIGUEZ3...
  - Contraseña temporal IGUAL para todos (decisión del usuario 26/11/2026), pero cada hash
    lleva su propia sal (PBKDF2-SHA256, 100000 iteraciones, mismo formato que HashContrasenasPbkdf2).
  - Todos quedan con DebeCambiarContrasena = 1: al primer acceso deben cambiarla.
  - La contraseña temporal NO se guarda en el repo: se pasa como parámetro.
  - Una persona = un usuario: si la misma persona está repetida como empleado (pasa en BABEL),
    solo se crea uno (ver comentario de la consulta).
  - Idempotente: solo crea usuarios para empleados activos SIN usuario. Se vuelve a correr
    después de la migración final (o cuando entren empleados nuevos).
  - Genera un CSV con IdEmpleado, nombre y usuario (SIN contraseña) para que RH avise a cada quien.
    Ese CSV tiene datos personales: no subirlo al repo.

  Uso:
    # Ver qué haría, sin escribir nada:
    powershell -ExecutionPolicy Bypass -File database\BABEL_UNIFICADA\18_seg_provisionar_usuarios.ps1 -ContrasenaTemporal '<temporal>' -Simular
    # Crear los usuarios:
    powershell -ExecutionPolicy Bypass -File database\BABEL_UNIFICADA\18_seg_provisionar_usuarios.ps1 -ContrasenaTemporal '<temporal>'
#>
param(
    [Parameter(Mandatory = $true)][string]$ContrasenaTemporal,
    [string]$Servidor = 'localhost',
    [string]$Salida = "C:\Users\sbasilio\Desktop\Trabajos\BABEL CRM\DOCUEMNTOS\usuarios_creados_$(Get-Date -Format 'yyyyMMdd_HHmm').csv",
    [switch]$Simular
)
$ErrorActionPreference = 'Stop'

# --- Misma regla que PoliticaContrasena del backend ---
$c = $ContrasenaTemporal
if ($c.Length -lt 8 -or $c.Length -gt 30 -or $c -cnotmatch '[A-Z]' -or $c -cnotmatch '[a-z]' -or $c -notmatch '\d' -or $c -notmatch '[^\p{L}\p{N}\s]') {
    throw 'La contraseña temporal no cumple la política: 8-30 caracteres, mayúscula, minúscula, número y carácter especial.'
}

function ConvertTo-HashPbkdf2([string]$Contrasena) {
    $salt = New-Object byte[] 16
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($salt)
    $kdf = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($Contrasena, $salt, 100000, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
    $clave = $kdf.GetBytes(32)
    $kdf.Dispose()
    return 'PBKDF2$SHA256$100000$' + [Convert]::ToBase64String($salt) + '$' + [Convert]::ToBase64String($clave)
}

function ConvertTo-Usuario([string]$Nombre, [string]$Paterno) {
    $base = ($Nombre.Trim().Substring(0, 1) + $Paterno).Normalize([Text.NormalizationForm]::FormD)
    $limpio = -join ($base.ToCharArray() | Where-Object {
        [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne [Globalization.UnicodeCategory]::NonSpacingMark })
    $limpio = ($limpio.ToUpperInvariant() -replace '[^A-Z]', '')
    if ($limpio.Length -gt 45) { $limpio = $limpio.Substring(0, 45) }
    return $limpio
}

$cadena = "Server=$Servidor;Database=BABEL_UNIFICADA;Integrated Security=True;TrustServerCertificate=True;Encrypt=False;"
$cn = New-Object System.Data.SqlClient.SqlConnection $cadena
$cn.Open()
try {
    # Usuarios que ya existen (para no repetir nombres).
    $existentes = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $cmd = $cn.CreateCommand()
    $cmd.CommandText = 'SELECT Usuario FROM seg.Usuario'
    $r = $cmd.ExecuteReader()
    while ($r.Read()) { [void]$existentes.Add($r.GetString(0)) }
    $r.Close()

    # Empleados activos sin usuario, UNO POR PERSONA.
    # BABEL da de alta otra vez a la misma persona por cartera o reingreso (40 personas repetidas
    # al 26/11/2026). Mientras la migración no las una en un solo empleado, una persona = un usuario:
    #  - si alguno de sus registros ya tiene usuario, no se crea otro;
    #  - si ninguno tiene, se crea para el registro con más cuentas asignadas y, a empate, el más antiguo.
    $cmd.CommandText = @'
WITH candidatos AS (
    SELECT e.IdEmpleado, e.Nombre, e.Paterno, ISNULL(e.Materno, '') AS Materno, e.IdPuesto, e.IdDepartamento,
           p.Nombre AS Puesto,
           ROW_NUMBER() OVER (
               PARTITION BY UPPER(LTRIM(RTRIM(e.Nombre)) + '|' + LTRIM(RTRIM(e.Paterno)) + '|' + LTRIM(RTRIM(ISNULL(e.Materno, '')))) COLLATE Latin1_General_CI_AI
               ORDER BY (SELECT COUNT(*) FROM ope.Cuenta c WHERE c.IdEmpleado = e.IdEmpleado) DESC,
                        e.FechaIngreso, e.IdEmpleado) AS Orden
    FROM rh.Empleado e
    JOIN rh.Puesto p ON p.IdPuesto = e.IdPuesto
    WHERE e.Activo = 1
      AND e.IdEmpleadoUnificado IS NULL
      AND NOT EXISTS (   -- la persona (cualquiera de sus registros activos) ya tiene usuario
            SELECT 1 FROM seg.Usuario u
            JOIN rh.Empleado x ON x.IdEmpleado = u.IdEmpleado
            WHERE x.Activo = 1
              AND LTRIM(RTRIM(x.Nombre))  COLLATE Latin1_General_CI_AI = LTRIM(RTRIM(e.Nombre))  COLLATE Latin1_General_CI_AI
              AND LTRIM(RTRIM(x.Paterno)) COLLATE Latin1_General_CI_AI = LTRIM(RTRIM(e.Paterno)) COLLATE Latin1_General_CI_AI
              AND LTRIM(RTRIM(ISNULL(x.Materno, ''))) COLLATE Latin1_General_CI_AI = LTRIM(RTRIM(ISNULL(e.Materno, ''))) COLLATE Latin1_General_CI_AI)
)
SELECT IdEmpleado, Nombre, Paterno, Materno, IdPuesto, IdDepartamento, Puesto
FROM candidatos
WHERE Orden = 1
ORDER BY IdEmpleado
'@
    $tabla = New-Object System.Data.DataTable
    $tabla.Load($cmd.ExecuteReader())

    $nuevos = @()
    foreach ($e in $tabla.Rows) {
        $base = ConvertTo-Usuario $e.Nombre $e.Paterno
        if ($base.Length -lt 2) { Write-Warning "Empleado $($e.IdEmpleado): nombre inválido, se omite."; continue }
        $usuario = $base; $n = 2
        while ($existentes.Contains($usuario)) { $usuario = "$base$n"; $n++ }
        [void]$existentes.Add($usuario)
        $nuevos += [pscustomobject]@{
            IdEmpleado     = [int]$e.IdEmpleado
            Nombre         = ("$($e.Nombre) $($e.Paterno) $($e.Materno)").Trim()
            Puesto         = $e.Puesto
            Usuario        = $usuario
            IdPuesto       = [byte]$e.IdPuesto
            IdDepartamento = [byte]$e.IdDepartamento
        }
    }

    Write-Host "Empleados activos sin usuario: $($tabla.Rows.Count). Usuarios a crear: $($nuevos.Count)."
    if ($nuevos.Count -eq 0) { return }
    $nuevos | Select-Object -First 10 IdEmpleado, Nombre, Usuario | Format-Table -AutoSize | Out-String | Write-Host

    if ($Simular) { Write-Host 'Simulación: no se escribió nada.'; return }

    $tx = $cn.BeginTransaction()
    try {
        $ins = $cn.CreateCommand()
        $ins.Transaction = $tx
        $ins.CommandText = @'
INSERT INTO seg.Usuario (Usuario, HashContrasena, IdEmpleado, IdPuesto, IdDepartamento, Activo, Bloqueado, DebeCambiarContrasena, FechaCambioContrasena)
VALUES (@Usuario, @Hash, @IdEmpleado, @IdPuesto, @IdDepartamento, 1, 0, 1, SYSDATETIME())
'@
        [void]$ins.Parameters.Add('@Usuario', [Data.SqlDbType]::VarChar, 50)
        [void]$ins.Parameters.Add('@Hash', [Data.SqlDbType]::VarChar, 200)
        [void]$ins.Parameters.Add('@IdEmpleado', [Data.SqlDbType]::Int)
        [void]$ins.Parameters.Add('@IdPuesto', [Data.SqlDbType]::TinyInt)
        [void]$ins.Parameters.Add('@IdDepartamento', [Data.SqlDbType]::TinyInt)

        $i = 0
        foreach ($u in $nuevos) {
            $ins.Parameters['@Usuario'].Value = $u.Usuario
            $ins.Parameters['@Hash'].Value = ConvertTo-HashPbkdf2 $ContrasenaTemporal
            $ins.Parameters['@IdEmpleado'].Value = $u.IdEmpleado
            $ins.Parameters['@IdPuesto'].Value = $u.IdPuesto
            $ins.Parameters['@IdDepartamento'].Value = $u.IdDepartamento
            [void]$ins.ExecuteNonQuery()
            $i++
            if ($i % 100 -eq 0) { Write-Host "  $i / $($nuevos.Count)..." }
        }
        $tx.Commit()
    }
    catch { $tx.Rollback(); throw }

    $nuevos | Select-Object IdEmpleado, Nombre, Puesto, Usuario | Export-Csv -Path $Salida -NoTypeInformation -Encoding UTF8
    Write-Host "Usuarios creados: $($nuevos.Count). Lista (sin contraseñas): $Salida"
}
finally { $cn.Close() }
