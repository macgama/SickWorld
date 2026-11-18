# Télécharge des modèles 3D Poly Haven (licence CC0, gratuits) en glTF, textures 1k.
# Lancement (PowerShell, depuis la racine du dépôt) :
#   powershell -ExecutionPolicy Bypass -Command "& .\tools\graphismes\polyhaven_modeles.ps1 -Dossier commun -Ids rock_07,tree_stump_01"
# Les fichiers vont dans game\assets\<Dossier>\modeles\<id>\<id>.gltf (+ .bin et textures).
# Déjà présents = ignorés. Un identifiant introuvable est signalé puis sauté.

param(
	[string]$Dossier = "commun",
	[string[]]$Ids = @(),
	[string]$Resolution = "1k"
)

$ErrorActionPreference = "Stop"
$entetes = @{ "User-Agent" = "SickWorld-asset-fetch" }
$racine = Join-Path $PSScriptRoot "..\..\game\assets\$Dossier\modeles"

function Telecharger($url, $destination) {
	if (Test-Path $destination) { return }
	New-Item -ItemType Directory -Force -Path (Split-Path $destination) | Out-Null
	Invoke-WebRequest -Uri $url -OutFile $destination -Headers $entetes -UseBasicParsing
}

foreach ($id in $Ids) {
	try { $fichiers = Invoke-RestMethod -Uri "https://api.polyhaven.com/files/$id" -Headers $entetes }
	catch { Write-Warning "$id : introuvable sur Poly Haven, ignoré"; continue }
	$gltf = $fichiers.gltf.$Resolution.gltf
	if ($null -eq $gltf) { Write-Warning "$id : pas de glTF $Resolution"; continue }
	$dossier_id = Join-Path $racine $id
	Telecharger $gltf.url (Join-Path $dossier_id "$id.gltf")
	foreach ($inclus in $gltf.include.PSObject.Properties) {
		Telecharger $inclus.Value.url (Join-Path $dossier_id ($inclus.Name -replace "/", "\"))
	}
	Write-Host "modele $id OK"
}
Write-Host "Terminé."
