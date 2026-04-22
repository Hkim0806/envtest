$ErrorActionPreference = "Stop"

$SopsVersion = "v3.12.2"
$AgeVersion = "v1.3.1"
$SopsSha256 = "5e777b1854ab2a6271d8f66375970e1fe3eea838251c309de151d16a2bdf13a2"
$AgeZipSha256 = "c56e8ce22f7e80cb85ad946cc82d198767b056366201d3e1a2b93d865be38154"

function Assert-FileSha256 {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [string]$Expected
  )

  if (-not (Test-Path $Path)) {
    throw "File not found for hash verification: $Path"
  }

  $actual = (Get-FileHash -Path $Path -Algorithm SHA256).Hash.ToLowerInvariant()
  $expectedNormalized = $Expected.ToLowerInvariant()

  if ($actual -ne $expectedNormalized) {
    throw "SHA256 mismatch for $Path`nExpected: $expectedNormalized`nActual  : $actual"
  }
}

Write-Host "[1/6] Preparing directories..."
$userBin = Join-Path $HOME "bin"
$ageDir = Join-Path $HOME ".config\sops\age"
$ageKeyFile = Join-Path $ageDir "keys.txt"

New-Item -ItemType Directory -Force -Path $userBin | Out-Null
New-Item -ItemType Directory -Force -Path $ageDir | Out-Null

Write-Host "[2/6] Installing sops + age binaries..."
$sopsUrl = "https://github.com/getsops/sops/releases/download/$SopsVersion/sops-$SopsVersion.amd64.exe"
$ageZipUrl = "https://github.com/FiloSottile/age/releases/download/$AgeVersion/age-$AgeVersion-windows-amd64.zip"
$sopsOut = Join-Path $userBin "sops.exe"

Invoke-WebRequest -Uri $sopsUrl -OutFile $sopsOut
Assert-FileSha256 -Path $sopsOut -Expected $SopsSha256

$zip = Join-Path $userBin "age-$AgeVersion-windows-amd64.zip"
$extract = Join-Path $userBin "age-extract"

Invoke-WebRequest -Uri $ageZipUrl -OutFile $zip
Assert-FileSha256 -Path $zip -Expected $AgeZipSha256
if (Test-Path $extract) { Remove-Item -Recurse -Force $extract }
Expand-Archive -Force -Path $zip -DestinationPath $extract
Copy-Item -Force (Join-Path $extract "age\age.exe") (Join-Path $userBin "age.exe")
Copy-Item -Force (Join-Path $extract "age\age-keygen.exe") (Join-Path $userBin "age-keygen.exe")
Remove-Item -Force $zip
Remove-Item -Recurse -Force $extract

Write-Host "[3/6] Updating USER PATH..."
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ([string]::IsNullOrWhiteSpace($userPath)) { $userPath = "" }

$parts = @($userPath -split ";" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
$exists = $false
foreach ($p in $parts) {
  if ($p.TrimEnd('\') -ieq $userBin.TrimEnd('\')) {
    $exists = $true
    break
  }
}
if (-not $exists) { $parts += $userBin }
[Environment]::SetEnvironmentVariable("Path", ($parts -join ";"), "User")

Write-Host "[4/6] Creating age key (if missing)..."
if (-not (Test-Path $ageKeyFile)) {
  & (Join-Path $userBin "age-keygen.exe") -o $ageKeyFile | Out-Null
} else {
  Write-Host "Existing key found: $ageKeyFile"
}

Write-Host "[5/6] Setting SOPS_AGE_KEY_FILE..."
[Environment]::SetEnvironmentVariable("SOPS_AGE_KEY_FILE", $ageKeyFile, "User")

Write-Host "[6/6] Installing global helper commands (encrypt/decrypt)..."
$encryptCmd = @'
@echo off
setlocal
for %%I in ("%CD%") do set "WORK_DIR=%%~fI"
set "SOPS_AGE_KEY_FILE=%USERPROFILE%\.config\sops\age\keys.txt"
if not exist "%SOPS_AGE_KEY_FILE%" set "SOPS_AGE_KEY_FILE=%APPDATA%\sops\age\keys.txt"
set "CONFIG_FILE=%WORK_DIR%\env_encrypt\.sops.yaml"
if not exist "%CONFIG_FILE%" set "CONFIG_FILE=%WORK_DIR%\.sops.yaml"
set "PLAIN_FILE=%~1"
set "ENC_FILE=%~2"
if "%PLAIN_FILE%"=="" set "PLAIN_FILE=%WORK_DIR%\.env"
if "%ENC_FILE%"=="" set "ENC_FILE=%WORK_DIR%\.env.enc"
sops --config "%CONFIG_FILE%" --filename-override .env encrypt --input-type dotenv --output-type dotenv --output "%ENC_FILE%" "%PLAIN_FILE%"
exit /b %ERRORLEVEL%
'@

$decryptCmd = @'
@echo off
setlocal
for %%I in ("%CD%") do set "WORK_DIR=%%~fI"
set "SOPS_AGE_KEY_FILE=%USERPROFILE%\.config\sops\age\keys.txt"
if not exist "%SOPS_AGE_KEY_FILE%" set "SOPS_AGE_KEY_FILE=%APPDATA%\sops\age\keys.txt"
set "ENC_FILE=%~1"
set "OUT_FILE=%~2"
if "%ENC_FILE%"=="" set "ENC_FILE=%WORK_DIR%\.env.enc"
if "%OUT_FILE%"=="" set "OUT_FILE=%WORK_DIR%\.env"
sops decrypt --filename-override .env "%ENC_FILE%" > "%OUT_FILE%"
exit /b %ERRORLEVEL%
'@

Set-Content -Path (Join-Path $userBin "encrypt.cmd") -Value $encryptCmd -Encoding ascii
Set-Content -Path (Join-Path $userBin "decrypt.cmd") -Value $decryptCmd -Encoding ascii
Set-Content -Path (Join-Path $userBin "encrpt.cmd") -Value "@echo off`r`ncall encrypt %*`r`n" -Encoding ascii

$publicKey = & (Join-Path $userBin "age-keygen.exe") -y $ageKeyFile

Write-Host ""
Write-Host "Setup completed."
Write-Host "- sops path: $(Join-Path $userBin 'sops.exe')"
Write-Host "- age path : $(Join-Path $userBin 'age.exe')"
Write-Host "- key file : $ageKeyFile"
Write-Host "- helper   : encrypt / decrypt / encrpt"
Write-Host "- public key: $publicKey"
Write-Host ""
Write-Host "IMPORTANT:"
Write-Host "1. Open a NEW terminal to use updated PATH."
Write-Host "2. Share only the public key above with your team."
Write-Host "3. Never share AGE-SECRET-KEY."
