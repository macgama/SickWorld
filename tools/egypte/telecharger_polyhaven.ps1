# Télécharge les ressources Poly Haven (licence CC0, gratuites) utilisées par l'île
# d'Égypte (Port des Marais, Carrières de Toura, Village des Bâtisseurs, Désert Rouge).
# Lancement (PowerShell, depuis la racine du dépôt) :
#   powershell -ExecutionPolicy Bypass -File tools\egypte\telecharger_polyhaven.ps1
# Les fichiers vont dans game\assets\egypte\ (textures\, modeles\ et ciel\).
# Déjà présents = ignorés. Une ressource introuvable est signalée puis sautée.

$ErrorActionPreference = "Stop"
$racine = Join-Path $PSScriptRoot "..\..\game\assets\egypte"
$entetes = @{ "User-Agent" = "SickWorld-asset-fetch" }

# Textures : identifiant Poly Haven -> résolution.
$textures = [ordered]@{
	# Sols : sable, limon du Nil, terre craquelée.
	"sand_01" = "2k"; "sand_02" = "2k"; "red_sand" = "2k"; "dense_sand" = "2k"; "damp_sand" = "2k";
	"dry_ground_01" = "2k"; "mud_cracked_dry_03" = "2k"; "mud_cracked_dry_riverbed_002" = "2k"; "brown_mud_03" = "2k";
	# Pierre : calcaire de Toura, blocs de la pyramide, falaises.
	"white_sandstone_blocks_02" = "2k"; "white_sandstone_bricks" = "2k"; "large_sandstone_blocks" = "2k";
	"sandstone_blocks_08" = "2k"; "sandstone_cracks" = "2k"; "quarry_wall" = "2k"; "quarry_wall_02" = "2k";
	# Briques crues, enduits d'argile, toits de roseaux.
	"clay_block_wall" = "2k"; "clay_plaster" = "2k"; "patterned_clay_plaster" = "2k"; "white_plaster_rough_01" = "2k";
	"reed_roof_04" = "2k"; "riet_01" = "2k";
	# Bois des barques et des quais, troncs de palmier.
	"weathered_planks" = "2k"; "palm_tree_bark" = "1k"
}
$cartes = @("Diffuse", "nor_gl", "arm")

# Modèles 3D (glTF, textures 1k) : poteries, paniers, rochers du désert, arbustes.
$modeles = @(
	"ceramic_vase_01", "ceramic_vase_02", "ceramic_vase_03", "ceramic_vase_04", "antique_ceramic_vase_01",
	"planter_pot_clay", "wicker_basket_01", "wicker_basket_02", "wooden_bowl_01", "wooden_bucket_01",
	"namaqualand_boulder_02", "namaqualand_boulder_03", "namaqualand_boulder_05", "namaqualand_cliff_01",
	"namaqualand_cliff_02", "sand_rocks_small_01", "shrub_01", "shrub_02", "grass_medium_01",
	"island_tree_01", "island_tree_02", "island_tree_03"
)

# Ciels sans sol (HDRI 2k, format .hdr) : midi, aube, coucher de soleil, nuit.
$ciels = @("qwantani_noon_puresky", "qwantani_dawn_puresky", "qwantani_sunset_puresky",
	"qwantani_dusk_2_puresky", "qwantani_night_puresky", "syferfontein_18d_clear_puresky")

function Telecharger($url, $destination) {
	if (Test-Path $destination) { return }
	New-Item -ItemType Directory -Force -Path (Split-Path $destination) | Out-Null
	Invoke-WebRequest -Uri $url -OutFile $destination -Headers $entetes -UseBasicParsing
}

function Fichiers($id) {
	try { return Invoke-RestMethod -Uri "https://api.polyhaven.com/files/$id" -Headers $entetes }
	catch { Write-Warning "$id : introuvable sur Poly Haven, ignoré"; return $null }
}

foreach ($id in $textures.Keys) {
	$res = $textures[$id]
	$fichiers = Fichiers $id
	if ($null -eq $fichiers) { continue }
	foreach ($carte in $cartes) {
		$info = $fichiers.$carte.$res.jpg
		if ($null -eq $info) { Write-Warning "$id : pas de carte $carte"; continue }
		Telecharger $info.url (Join-Path $racine "textures\$id\${id}_$carte.jpg")
	}
	Write-Host "texture $id OK"
}

foreach ($id in $modeles) {
	$fichiers = Fichiers $id
	if ($null -eq $fichiers) { continue }
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
	$fichiers = Fichiers $id
	if ($null -eq $fichiers) { continue }
	$info = $fichiers.hdri."2k".hdr
	if ($null -eq $info) { Write-Warning "$id : pas de HDRI 2k"; continue }
	Telecharger $info.url (Join-Path $racine "ciel\$id.hdr")
	Write-Host "ciel $id OK"
}
Write-Host "Terminé."
