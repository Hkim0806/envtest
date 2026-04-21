@echo off
call "%~dp0env_encrypt\scripts\env-crypto.bat" decrypt %*
exit /b %ERRORLEVEL%
