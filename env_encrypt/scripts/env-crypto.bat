@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "WORK_DIR=%CD%"

if "%~1"=="" goto :usage
if /I "%~1"=="encrypt" goto :encrypt
if /I "%~1"=="decrypt" goto :decrypt
if /I "%~1"=="-h" goto :usage
if /I "%~1"=="--help" goto :usage

echo [ERROR] Unknown mode: %~1
goto :usage

:setup
set "SHELL_KIND=cmd_or_powershell"
if defined MSYSTEM set "SHELL_KIND=git-bash"
set "SOPS_CONFIG_FILE=%WORK_DIR%\env_encrypt\.sops.yaml"
if not exist "%SOPS_CONFIG_FILE%" set "SOPS_CONFIG_FILE=%WORK_DIR%\.sops.yaml"

set "SOPS_AGE_KEY_FILE=%USERPROFILE%\.config\sops\age\keys.txt"
if not exist "%SOPS_AGE_KEY_FILE%" (
  set "SOPS_AGE_KEY_FILE=%APPDATA%\sops\age\keys.txt"
)
if not exist "%SOPS_AGE_KEY_FILE%" (
  echo [ERROR] Key file not found.
  echo         Checked:
  echo         - %USERPROFILE%\.config\sops\age\keys.txt
  echo         - %APPDATA%\sops\age\keys.txt
  echo Run env_encrypt\install\setup-secrets-windows.bat first.
  exit /b 1
)
where sops >nul 2>nul
if errorlevel 1 (
  echo [ERROR] sops command not found in PATH.
  exit /b 1
)
echo [INFO] Shell: %SHELL_KIND%
echo [INFO] Key  : %SOPS_AGE_KEY_FILE%
echo [INFO] Work : %WORK_DIR%
echo [INFO] SOPS config: %SOPS_CONFIG_FILE%
exit /b 0

:encrypt
call :setup
if errorlevel 1 exit /b 1
set "PLAIN_FILE=%~2"
set "ENC_FILE=%~3"
if "%PLAIN_FILE%"=="" set "PLAIN_FILE=%WORK_DIR%\.env"
if "%ENC_FILE%"=="" set "ENC_FILE=%WORK_DIR%\.env.enc"
if not exist "%PLAIN_FILE%" (
  echo [ERROR] Plain env file not found: %PLAIN_FILE%
  exit /b 1
)
echo Encrypting "%PLAIN_FILE%" to "%ENC_FILE%"...
sops --config "%SOPS_CONFIG_FILE%" --filename-override .env encrypt --input-type dotenv --output-type dotenv --output "%ENC_FILE%" "%PLAIN_FILE%"
if errorlevel 1 exit /b 1
echo [OK] Encrypted: %ENC_FILE%
exit /b 0

:decrypt
call :setup
if errorlevel 1 exit /b 1
set "ENC_FILE=%~2"
set "OUT_FILE=%~3"
if "%ENC_FILE%"=="" set "ENC_FILE=%WORK_DIR%\.env.enc"
if "%OUT_FILE%"=="" set "OUT_FILE=%WORK_DIR%\.env"
if not exist "%ENC_FILE%" (
  echo [ERROR] Encrypted file not found: %ENC_FILE%
  exit /b 1
)
echo Decrypting "%ENC_FILE%" to "%OUT_FILE%"...
sops decrypt --filename-override .env "%ENC_FILE%" > "%OUT_FILE%"
if errorlevel 1 exit /b 1
echo [OK] Decrypted: %OUT_FILE%
exit /b 0

:usage
echo Usage:
echo   env_encrypt\scripts\env-crypto.bat encrypt [plain_file] [enc_file]
echo   env_encrypt\scripts\env-crypto.bat decrypt [enc_file] [out_file]
echo.
echo Examples:
echo   env_encrypt\scripts\env-crypto.bat encrypt
echo   env_encrypt\scripts\env-crypto.bat decrypt
echo   env_encrypt\scripts\env-crypto.bat encrypt .env .env.enc
echo   env_encrypt\scripts\env-crypto.bat decrypt .env.enc .env
exit /b 1
