@echo off
rem Éteint le serveur de comptes SickWorld.
set "DOSSIER=%USERPROFILE%\Documents\SickWorld_serveur"
taskkill /IM nakama.exe /F >nul 2>&1
"%DOSSIER%\pgsql\bin\pg_ctl.exe" -D "%DOSSIER%\base" -w stop
echo Serveur eteint.
