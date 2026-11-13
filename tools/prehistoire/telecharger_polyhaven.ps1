# Télécharge les ressources Poly Haven (licence CC0, gratuites) utilisées par l'île
# de la Préhistoire (Côte Gelée).
# Lancement (PowerShell, depuis la racine du dépôt) :
#   powershell -ExecutionPolicy Bypass -File tools\prehistoire\telecharger_polyhaven.ps1
# Les fichiers vont dans game\assets\prehistoire\ (textures\, modeles\ et ciel\).
# Déjà présents = ignorés.

$ErrorActionPreference = "Stop"
$racine = Join-Path $PSScriptRoot "..\..\game\assets\prehistoire"
$entetes = @{ "User-Agent" = "SickWorld-asset-fetch" }

# Textures du sol et des roches : identifiant Poly Haven -> résolution.
$textures = [ordered]@{
	"dry_river_pebbles" = "2k"; "clean_pebbles" = "2k";
	"snow_02" = "2k"; "snow_03" = "2k";
	"dry_ground_rocks" = "2k"; "brown_mud_rocks_01" = "2k";
	"cliff_side" = "2k"; "rock_wall_10" = "2k"; "rock_boulder_dry" = "2k";
	"rough_wood" = "1k"; "bark_willow_02" = "1k";
	# Steppe des Mammouths : herbe sèche, berge boueuse, peau des tentes.
	"withered_grass" = "2k"; "brown_mud_02" = "2k"; "brown_leather" = "2k"
}
$cartes = @("Diffuse", "nor_gl", "arm")

# Modèles 3D (glTF, textures 1k) : rochers, falaises, bois mort.
$modeles = @(
	"rock_07", "rock_09", "stone_01", "boulder_01",
	"rock_face_01", "rock_face_02", "rock_moss_set_01", "rock_moss_set_02",
	"namaqualand_boulder_04", "dead_tree_trunk", "dead_tree_trunk_02",
	"tree_stump_01", "dry_branches_medium_01",
	# Steppe des Mammouths : touffes d'herbe, buisson sec, arbuste isolé.
	"grass_medium_02", "grass_bermuda_01", "wild_rooibos_bush", "searsia_lucida"
)

# Ciels (HDRI 2k, format .hdr).
$ciels = @("kloofendal_misty_morning_puresky", "table_mountain_1_puresky", "snow_field_2_puresky")

function Telecharger($url, $destination) {
	if (Test-Path $destination) { return }
	New-Item -ItemType Directory -Force -Path (Split-Path $destination) | Out-Null
	Invoke-WebRequest -Uri $url -OutFile $destination -Headers $entetes -UseBasicParsing
}

foreach ($id in $textures.Keys) {
	$res = $textures[$id]
	$fichiers = Invoke-RestMethod -Uri "https://api.polyhaven.com/files/$id" -Headers $entetes
	foreach ($carte in $cartes) {
		$info = $fichiers.$carte.$res.jpg
		if ($null -eq $info) { Write-Warning "$id : pas de carte $carte"; continue }
		Telecharger $info.url (Join-Path $racine "textures\$id\${id}_$carte.jpg")
	}
	Write-Host "texture $id OK"
}

foreach ($id in $modeles) {
	$fichiers = Invoke-RestMethod -Uri "https://api.polyhaven.com/files/$id" -Headers $entetes
	$gltf = $fichiers.gltf."1k".gltf
	if ($null -eq $gltf) { Write-Warning "$id : pas de glTF 1k"; continue }
	$dossier = Join-Path $racine "modeles\$id"
	Telecharger $gltf.url (Join-Path $dossier "$id.gltf")
	foreach ($inclus in $gltf.include.PSObject.Properties) {
		Telecharger $inclus.Value.url (Join-Path $dossier ($inclus.Name -replace "/", "\"))
	}
	Write-Host "modele $id OK"
}

foreach ($id in $ciels) {
	$fichiers = Invoke-RestMethod -Uri "https://api.polyhaven.com/files/$id" -Headers $entetes
	$info = $fichiers.hdri."2k".hdr
	if ($null -eq $info) { Write-Warning "$id : pas de HDRI 2k"; continue }
	Telecharger $info.url (Join-Path $racine "ciel\$id.hdr")
	Write-Host "ciel $id OK"
}
Write-Host "Terminé."
