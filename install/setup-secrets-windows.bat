@echo off
setlocal enableextensions enabledelayedexpansion

echo [1/5] Preparing directories...
set "USER_BIN=%USERPROFILE%\bin"
set "AGE_DIR=%USERPROFILE%\.config\sops\age"
set "AGE_KEY_FILE=%AGE_DIR%\keys.txt"
if not exist "%USER_BIN%" mkdir "%USER_BIN%"
if not exist "%AGE_DIR%" mkdir "%AGE_DIR%"

echo [2/5] Installing sops + age binaries...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$bin = Join-Path $HOME 'bin';" ^
  "New-Item -ItemType Directory -Force -Path $bin | Out-Null;" ^
  "$sopsUrl = 'https://github.com/getsops/sops/releases/download/v3.12.2/sops-v3.12.2.amd64.exe';" ^
  "$ageZipUrl = 'https://dl.filippo.io/age/v1.3.1?for=windows/amd64';" ^
  "Invoke-WebRequest -Uri $sopsUrl -OutFile (Join-Path $bin 'sops.exe');" ^
  "$zip = Join-Path $bin 'age-v1.3.1-windows-amd64.zip';" ^
  "Invoke-WebRequest -Uri $ageZipUrl -OutFile $zip;" ^
  "$extract = Join-Path $bin 'age-extract';" ^
  "if (Test-Path $extract) { Remove-Item -Recurse -Force $extract };" ^
  "Expand-Archive -Force -Path $zip -DestinationPath $extract;" ^
  "Copy-Item -Force (Join-Path $extract 'age\age.exe') (Join-Path $bin 'age.exe');" ^
  "Copy-Item -Force (Join-Path $extract 'age\age-keygen.exe') (Join-Path $bin 'age-keygen.exe');" ^
  "Remove-Item -Force $zip;" ^
  "Remove-Item -Recurse -Force $extract;"
if errorlevel 1 (
  echo [ERROR] Failed to install binaries.
  exit /b 1
)

echo [3/5] Updating USER PATH...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$bin = Join-Path $HOME 'bin';" ^
  "$userPath = [Environment]::GetEnvironmentVariable('Path','User');" ^
  "if ([string]::IsNullOrWhiteSpace($userPath)) { $userPath = '' };" ^
  "$parts = @($userPath -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' });" ^
  "$exists = $false;" ^
  "foreach ($p in $parts) { if ($p.TrimEnd('\') -ieq $bin.TrimEnd('\')) { $exists = $true; break } };" ^
  "if (-not $exists) { $parts += $bin };" ^
  "$newPath = ($parts -join ';');" ^
  "[Environment]::SetEnvironmentVariable('Path', $newPath, 'User');"
if errorlevel 1 (
  echo [ERROR] Failed to update USER PATH.
  exit /b 1
)

echo [4/5] Creating age key (if missing)...
if not exist "%AGE_KEY_FILE%" (
  "%USER_BIN%\age-keygen.exe" -o "%AGE_KEY_FILE%"
  if errorlevel 1 (
    echo [ERROR] Failed to generate age key.
    exit /b 1
  )
) else (
  echo Existing key found: %AGE_KEY_FILE%
)

echo [5/5] Setting SOPS_AGE_KEY_FILE and printing public key...
setx SOPS_AGE_KEY_FILE "%AGE_KEY_FILE%" >nul
for /f "usebackq delims=" %%A in (`"%USER_BIN%\age-keygen.exe" -y "%AGE_KEY_FILE%"`) do set "AGE_PUBLIC_KEY=%%A"

echo.
echo Setup completed.
echo - sops path: %USER_BIN%\sops.exe
echo - age path: %USER_BIN%\age.exe
echo - key file : %AGE_KEY_FILE%
echo - public key: %AGE_PUBLIC_KEY%
echo.
echo IMPORTANT:
echo 1. Open a NEW terminal to use updated PATH.
echo 2. Share only the public key above with your team.
echo 3. Never share AGE-SECRET-KEY.

endlocal

