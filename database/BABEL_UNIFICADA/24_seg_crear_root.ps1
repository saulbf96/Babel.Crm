<#
  BABEL_UNIFICADA - 24. Usuario ROOT dedicado (26/11/2026).

  Regla del usuario: ROOT es un perfil aparte del administrador del día a día.
  - Crea el usuario ROOT (si no existe): sin empleado, EsRoot = 1, cambio de
    contraseña obligatorio al primer acceso. Tiene TODOS los permisos y es el
    único que puede cambiarse sus propios permisos.
  - Quita el ROOT a cualquier otro usuario (ADMIN queda como administrador normal).
  - Nunca deja la base sin ROOT.
  - La contraseña temporal NO se guarda en el repo: se pasa como parámetro
    (normalmente la misma de Seguridad:ContrasenaTemporal).
  Requiere los scripts 04 y 23. Idempotente.

  Uso:
    powershell -ExecutionPolicy Bypass -File database\BABEL_UNIFICADA\24_seg_crear_root.ps1 -ContrasenaTemporal '<temporal>'
#>
param(
    [Parameter(Mandatory = $true)][string]$ContrasenaTemporal,
    [string]$Usuario = 'ROOT',
    [string]$Servidor = 'localhost'
)
$ErrorActionPreference = 'Stop'

$c = $ContrasenaTemporal
if ($c.Length -lt 8 -or $c.Length -gt 30 -or $c -cnotmatch '[A-Z]' -or $c -cnotmatch '[a-z]' -or $c -notmatch '\d' -or $c -notmatch '[^\p{L}\p{N}\s]') {
    throw 'La contraseña temporal no cumple la política: 8-30 caracteres, mayúscula, minúscula, número y carácter especial.'
}

# Mismo formato que HashContrasenasPbkdf2 del backend.
$salt = New-Object byte[] 16
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($salt)
$kdf = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($c, $salt, 100000, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
$hash = 'PBKDF2$SHA256$100000$' + [Convert]::ToBase64String($salt) + '$' + [Convert]::ToBase64String($kdf.GetBytes(32))
$kdf.Dispose()

$cn = New-Object System.Data.SqlClient.SqlConnection "Server=$Servidor;Database=BABEL_UNIFICADA;Integrated Security=True;TrustServerCertificate=True;Encrypt=False;"
$cn.Open()
try {
    $cmd = $cn.CreateCommand()
    $cmd.CommandText = @'
SET XACT_ABORT ON;
BEGIN TRAN;
IF NOT EXISTS (SELECT 1 FROM seg.Usuario WHERE Usuario = @Usuario)
BEGIN
    -- Puesto/departamento solo porque las columnas son obligatorias; ROOT no depende del puesto.
    INSERT INTO seg.Usuario (Usuario, HashContrasena, IdEmpleado, IdPuesto, IdDepartamento,
                             Activo, Bloqueado, DebeCambiarContrasena, FechaCambioContrasena, EsRoot)
    SELECT @Usuario, @Hash, NULL, a.IdPuesto, a.IdDepartamento, 1, 0, 1, SYSDATETIME(), 1
    FROM (SELECT TOP 1 IdPuesto, IdDepartamento FROM seg.Usuario ORDER BY IdUsuario) a;
    SELECT 'creado' AS Resultado;
END
ELSE
BEGIN
    UPDATE seg.Usuario SET EsRoot = 1, Activo = 1 WHERE Usuario = @Usuario;
    SELECT 'ya existía' AS Resultado;
END
-- Solo el usuario ROOT dedicado es ROOT.
UPDATE seg.Usuario SET EsRoot = 0 WHERE Usuario <> @Usuario AND EsRoot = 1;
INSERT INTO log.Auditoria (Usuario, Accion, Entidad, IdEntidad, Detalle)
SELECT 'SCRIPT_24', 'ROOT', 'seg.Usuario', CAST(IdUsuario AS varchar(20)), 'Usuario ROOT dedicado'
FROM seg.Usuario WHERE Usuario = @Usuario;
COMMIT;
'@
    [void]$cmd.Parameters.Add('@Usuario', [Data.SqlDbType]::VarChar, 50)
    [void]$cmd.Parameters.Add('@Hash', [Data.SqlDbType]::VarChar, 200)
    $cmd.Parameters['@Usuario'].Value = $Usuario
    $cmd.Parameters['@Hash'].Value = $hash
    $resultado = $cmd.ExecuteScalar()
    Write-Host "Usuario $Usuario $resultado."

    $cmd2 = $cn.CreateCommand()
    $cmd2.CommandText = 'SELECT Usuario, EsRoot, DebeCambiarContrasena, IdEmpleado FROM seg.Usuario WHERE EsRoot = 1 OR Usuario = ''ADMIN'''
    $r = $cmd2.ExecuteReader()
    while ($r.Read()) { Write-Host ("  {0}: EsRoot={1}, CambioPendiente={2}, Empleado={3}" -f $r[0], $r[1], $r[2], ($(if ($r.IsDBNull(3)) { 'ninguno' } else { $r[3] }))) }
    $r.Close()
}
finally { $cn.Close() }
