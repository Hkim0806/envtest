@echo off
if /I "%~1"=="-h" (
  call "%~dp0env_encrypt\scripts\env-crypto.bat" --help
  exit /b %ERRORLEVEL%
)
if /I "%~1"=="--help" (
  call "%~dp0env_encrypt\scripts\env-crypto.bat" --help
  exit /b %ERRORLEVEL%
)
call "%~dp0env_encrypt\scripts\env-crypto.bat" decrypt %*
exit /b %ERRORLEVEL%
