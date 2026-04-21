@echo off
call "%~dp0env_encrypt\scripts\env-crypto.bat" encrypt %*
exit /b %ERRORLEVEL%

