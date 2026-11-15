# Cherche ou télécharge des textures Poly Haven (licence CC0, gratuites).
# Lancement (PowerShell, depuis la racine du dépôt) :
#   Chercher :     powershell -ExecutionPolicy Bypass -File tools\graphismes\polyhaven_textures.ps1 -Chercher marble,roof,bark
#   Télécharger :  powershell -ExecutionPolicy Bypass -File tools\graphismes\polyhaven_textures.ps1 -Dossier grece -Ids marble_01,roof_tiles_14 [-Resolution 2k]
# Les fichiers vont dans game\assets\<Dossier>\textures\<id>\<id>_<carte>.jpg. Déjà présents = ignorés.
# Un identifiant inconnu est signalé puis ignoré (le script continue).

param(
	[string[]]$Chercher = @(),
	[string]$Dossier = "",
	[string[]]$Ids = @(),
	[string]$Resolution = "2k"
)

$ErrorActionPreference = "Stop"
$entetes = @{ "User-Agent" = "SickWorld-asset-fetch" }

if ($Chercher.Count -gt 0) {
	$tout = Invoke-RestMethod -Uri "https://api.polyhaven.com/assets?t=textures" -Headers $entetes
	foreach ($mot in $Chercher) {
		$trouves = $tout.PSObject.Properties.Name | Where-Object { $_ -like "*$mot*" } | Sort-Object
		Write-Host ("[{0}] {1}" -f $mot, ($trouves -join ", "))
	}
	exit 0
}

$racine = Join-Path $PSScriptRoot "..\..\game\assets\$Dossier\textures"
$cartes = @("Diffuse", "nor_gl", "arm")
foreach ($id in $Ids) {
	try {
		$fichiers = Invoke-RestMethod -Uri "https://api.polyhaven.com/files/$id" -Headers $entetes
	} catch {
		Write-Warning "$id : introuvable sur Poly Haven"
		continue
	}
	foreach ($carte in $cartes) {
		$info = $fichiers.$carte.$Resolution.jpg
		if ($null -eq $info) { Write-Warning "$id : pas de carte $carte"; continue }
		$destination = Join-Path $racine "$id\${id}_$carte.jpg"
		if (Test-Path $destination) { continue }
		New-Item -ItemType Directory -Force -Path (Split-Path $destination) | Out-Null
		Invoke-WebRequest -Uri $info.url -OutFile $destination -Headers $entetes -UseBasicParsing
	}
	Write-Host "texture $id OK"
}
Write-Host "Terminé."
