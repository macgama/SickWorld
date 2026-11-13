# Installe le serveur de comptes SickWorld (Nakama + PostgreSQL) sur ce PC Windows.
# Tout est gratuit, sans droits administrateur, et rangé dans un seul dossier :
#   Documents\SickWorld_serveur\
# À lancer une seule fois (clic droit > Exécuter avec PowerShell), ou :
#   powershell -ExecutionPolicy Bypass -File serveur\windows\installer_serveur.ps1
# Ensuite : demarrer_serveur.bat pour l'allumer, arreter_serveur.bat pour l'éteindre.

param(
    [string]$Dossier = (Join-Path ([Environment]::GetFolderPath("MyDocuments")) "SickWorld_serveur")
)
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"   # téléchargements beaucoup plus rapides

$VersionNakama = "3.38.0"
# Versions de PostgreSQL essayées dans l'ordre (archives « binaries » d'EnterpriseDB).
$VersionsPostgres = @("17.6-1", "17.5-1", "17.4-1", "16.10-1", "16.9-1", "16.8-1")

New-Item -ItemType Directory -Force -Path $Dossier | Out-Null
$Telechargements = Join-Path $Dossier "telechargements"
New-Item -ItemType Directory -Force -Path $Telechargements | Out-Null

# --- 1. Nakama -------------------------------------------------------------------
$Nakama = Join-Path $Dossier "nakama\nakama.exe"
if (-not (Test-Path $Nakama)) {
    Write-Host "Téléchargement de Nakama $VersionNakama…"
    $archive = Join-Path $Telechargements "nakama.tar.gz"
    Invoke-WebRequest "https://github.com/heroiclabs/nakama/releases/download/v$VersionNakama/nakama-$VersionNakama-windows-amd64.tar.gz" -OutFile $archive
    New-Item -ItemType Directory -Force -Path (Join-Path $Dossier "nakama") | Out-Null
    tar -xzf $archive -C (Join-Path $Dossier "nakama")
}
Write-Host "Nakama : OK"

# --- 2. PostgreSQL (version portable, sans installation) -----------------------
$Pg = Join-Path $Dossier "pgsql\bin"
if (-not (Test-Path (Join-Path $Pg "pg_ctl.exe"))) {
    $archive = Join-Path $Telechargements "postgresql.zip"
    $ok = $false
    foreach ($v in $VersionsPostgres) {
        try {
            Write-Host "Téléchargement de PostgreSQL $v…"
            Invoke-WebRequest "https://get.enterprisedb.com/postgresql/postgresql-$v-windows-x64-binaries.zip" -OutFile $archive
            $ok = $true
            break
        } catch { Write-Host "  (pas disponible, on essaie une autre version)" }
    }
    if (-not $ok) { throw "Impossible de télécharger PostgreSQL." }
    Expand-Archive -Path $archive -DestinationPath $Dossier -Force
}
Write-Host "PostgreSQL : OK"

# --- 3. Base de données ----------------------------------------------------------
$Donnees = Join-Path $Dossier "base"
if (-not (Test-Path (Join-Path $Donnees "PG_VERSION"))) {
    Write-Host "Création de la base de données…"
    # Accessible seulement depuis ce PC (127.0.0.1), sans mot de passe.
    & (Join-Path $Pg "initdb.exe") -D $Donnees -U postgres --auth=trust -E UTF8 --locale=C | Out-Host
}
# Lancé en arrière-plan : avec « pg_ctl start » le script restait bloqué (sortie gardée ouverte).
Start-Process -FilePath (Join-Path $Pg "postgres.exe") -ArgumentList @("-D", "`"$Donnees`"", "-p", "5432", "-h", "127.0.0.1") -WindowStyle Hidden -RedirectStandardError (Join-Path $Dossier "postgres.log")
$pret = $false
for ($i = 0; $i -lt 60; $i++) {
    & (Join-Path $Pg "pg_isready.exe") -h 127.0.0.1 -p 5432 | Out-Null
    if ($LASTEXITCODE -eq 0) { $pret = $true; break }
    Start-Sleep -Seconds 1
}
if (-not $pret) { throw "PostgreSQL n'a pas démarré (voir $Dossier\postgres.log)." }
& (Join-Path $Pg "psql.exe") -h 127.0.0.1 -U postgres -tc "SELECT 1 FROM pg_database WHERE datname='nakama'" | Out-String | ForEach-Object {
    if ($_.Trim() -ne "1") { & (Join-Path $Pg "createdb.exe") -h 127.0.0.1 -U postgres nakama }
}
& $Nakama migrate up --database.address "postgres:@127.0.0.1:5432/nakama" 2>&1 | Out-Host
& (Join-Path $Pg "pg_ctl.exe") -D $Donnees -w stop | Out-Host

Remove-Item -Recurse -Force $Telechargements
Write-Host ""
Write-Host "C'est installé dans $Dossier"
Write-Host "Pour allumer le serveur : double-clic sur serveur\windows\demarrer_serveur.bat"
