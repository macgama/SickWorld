@echo off
chcp 65001 >nul
rem Allume le serveur de comptes SickWorld (PostgreSQL + Nakama) sur ce PC.
rem Laisse cette fenêtre ouverte pendant que tu joues ; ferme-la (ou lance
rem arreter_serveur.bat) pour l'éteindre.
set "DOSSIER=%USERPROFILE%\Documents\SickWorld_serveur"
set "CONFIG=%~dp0..\nakama\config.yml"
if not exist "%DOSSIER%\nakama\nakama.exe" (
  echo Le serveur n'est pas encore installe : lance d'abord installer_serveur.ps1
  pause
  exit /b 1
)
"%DOSSIER%\pgsql\bin\pg_ctl.exe" -D "%DOSSIER%\base" -o "-p 5432 -h 127.0.0.1" -l "%DOSSIER%\postgres.log" -w status >nul 2>&1
if errorlevel 1 "%DOSSIER%\pgsql\bin\pg_ctl.exe" -D "%DOSSIER%\base" -o "-p 5432 -h 127.0.0.1" -l "%DOSSIER%\postgres.log" -w start
"%DOSSIER%\nakama\nakama.exe" migrate up --database.address "postgres:@127.0.0.1:5432/nakama" >nul 2>&1
cd /d "%DOSSIER%"
echo.
echo  Serveur de comptes SickWorld allume : 127.0.0.1:7350
echo  Console d'administration : http://127.0.0.1:7351  (admin / voir config.yml)
echo  Ferme cette fenetre pour l'eteindre.
echo.
"%DOSSIER%\nakama\nakama.exe" --config "%CONFIG%" --database.address "postgres:@127.0.0.1:5432/nakama" > "%DOSSIER%\nakama.log" 2>&1
"%DOSSIER%\pgsql\bin\pg_ctl.exe" -D "%DOSSIER%\base" -w stop
