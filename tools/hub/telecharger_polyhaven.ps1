# Télécharge les ressources Poly Haven (licence CC0, gratuites) utilisées par le hub Hikari Bay.
# Lancement (PowerShell, depuis la racine du dépôt) :
#   powershell -ExecutionPolicy Bypass -File tools\hub\telecharger_polyhaven.ps1
# Les fichiers vont dans game\assets\hub\ (textures\ et modeles\). Déjà présents = ignorés.

$ErrorActionPreference = "Stop"
$racine = Join-Path $PSScriptRoot "..\..\game\assets\hub"
$entetes = @{ "User-Agent" = "SickWorld-asset-fetch" }

# Textures : identifiant Poly Haven -> résolution.
$textures = [ordered]@{
	"concrete_pavers_02" = "2k"; "asphalt_02" = "2k"; "concrete_pavement" = "2k";
	"concrete_tile_facade" = "1k"; "rectangular_facade_tiles" = "1k"; "concrete_wall_008" = "1k";
	"painted_metal_shutter" = "1k"; "metal_plate" = "1k"; "square_tiled_wall" = "1k";
	"terrazzo_tiles" = "1k"; "granite_tile" = "1k"; "brushed_concrete" = "1k";
	"white_rough_plaster" = "1k"; "corrugated_iron" = "1k"
}
$cartes = @("Diffuse", "nor_gl", "arm")

# Modèles 3D (glTF, textures 1k).
$modeles = @(
	"street_lamp_01", "street_lamp_02", "fire_hydrant", "metal_trash_can",
	"exterior_aircon_unit", "utility_box_01", "water_manhole_cover", "concrete_road_barrier",
	"rollershutter_door", "rollershutter_window_01",
	"security_light", "potted_plant_01",
	"planter_box_01",
	"korean_public_payphone_01", "security_camera_01", "plastic_crate_01", "cardboard_box_01",
	"trashbag", "gothic_statue", "modular_chainlink_fence"
)

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
Write-Host "Terminé."
