@echo off
call "%~dp0scripts\env-crypto.bat" encrypt %*
exit /b %ERRORLEVEL%

