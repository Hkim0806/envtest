$ErrorActionPreference = "Stop"

Write-Host "[1/5] Preparing directories..."
$userBin = Join-Path $HOME "bin"
$ageDir = Join-Path $HOME ".config\sops\age"
$ageKeyFile = Join-Path $ageDir "keys.txt"

New-Item -ItemType Directory -Force -Path $userBin | Out-Null
New-Item -ItemType Directory -Force -Path $ageDir | Out-Null

Write-Host "[2/5] Installing sops + age binaries..."
$sopsUrl = "https://github.com/getsops/sops/releases/download/v3.12.2/sops-v3.12.2.amd64.exe"
$ageZipUrl = "https://dl.filippo.io/age/v1.3.1?for=windows/amd64"

Invoke-WebRequest -Uri $sopsUrl -OutFile (Join-Path $userBin "sops.exe")

$zip = Join-Path $userBin "age-v1.3.1-windows-amd64.zip"
$extract = Join-Path $userBin "age-extract"

Invoke-WebRequest -Uri $ageZipUrl -OutFile $zip
if (Test-Path $extract) { Remove-Item -Recurse -Force $extract }
Expand-Archive -Force -Path $zip -DestinationPath $extract
Copy-Item -Force (Join-Path $extract "age\age.exe") (Join-Path $userBin "age.exe")
Copy-Item -Force (Join-Path $extract "age\age-keygen.exe") (Join-Path $userBin "age-keygen.exe")
Remove-Item -Force $zip
Remove-Item -Recurse -Force $extract

Write-Host "[3/5] Updating USER PATH..."
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

Write-Host "[4/5] Creating age key (if missing)..."
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
set "SOPS_AGE_KEY_FILE=%USERPROFILE%\.config\sops\age\keys.txt"
if not exist "%SOPS_AGE_KEY_FILE%" set "SOPS_AGE_KEY_FILE=%APPDATA%\sops\age\keys.txt"
set "CONFIG_FILE=%CD%\env_encrypt\.sops.yaml"
if not exist "%CONFIG_FILE%" set "CONFIG_FILE=%CD%\.sops.yaml"
set "PLAIN_FILE=%~1"
set "ENC_FILE=%~2"
if "%PLAIN_FILE%"=="" set "PLAIN_FILE=.env"
if "%ENC_FILE%"=="" set "ENC_FILE=.env.enc"
sops --config "%CONFIG_FILE%" --filename-override .env encrypt --input-type dotenv --output-type dotenv --output "%ENC_FILE%" "%PLAIN_FILE%"
exit /b %ERRORLEVEL%
'@

$decryptCmd = @'
@echo off
setlocal
set "SOPS_AGE_KEY_FILE=%USERPROFILE%\.config\sops\age\keys.txt"
if not exist "%SOPS_AGE_KEY_FILE%" set "SOPS_AGE_KEY_FILE=%APPDATA%\sops\age\keys.txt"
set "ENC_FILE=%~1"
set "OUT_FILE=%~2"
if "%ENC_FILE%"=="" set "ENC_FILE=.env.enc"
if "%OUT_FILE%"=="" set "OUT_FILE=.env"
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
