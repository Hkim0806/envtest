@echo off
call "%~dp0scripts\env-crypto.bat" decrypt %*
exit /b %ERRORLEVEL%

