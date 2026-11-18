# Télécharge depuis Poly Haven (API publique) les cartes de couleur PNG (avec transparence)
# et les éventuelles cartes alpha/opacité en 1k des modèles listés, dans un dossier de travail.
# Usage : powershell -ExecutionPolicy Bypass -File tools\graphismes\polyhaven_alpha.ps1 -Sortie <dossier>
param(
	[string]$Sortie = "alpha_polyhaven",
	[string[]]$Ids = @("dandelion_01","fern_02","nettle_plant","shrub_03","shrub_04","shrub_sorrel_01","weed_plant_02","wooden_broom","grass_medium_01","island_tree_01","island_tree_02","island_tree_03","shrub_01","shrub_02","grass_medium_02","searsia_lucida","wild_rooibos_bush","potted_plant_01","modular_chainlink_fence")
)
$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $Sortie | Out-Null
$rapport = @()
foreach ($id in $Ids) {
	$d = Join-Path $Sortie $id
	New-Item -ItemType Directory -Force -Path $d | Out-Null
	$fichiers = Invoke-RestMethod "https://api.polyhaven.com/files/$id"
	foreach ($carte in $fichiers.PSObject.Properties) {
		if ($carte.Name -in @("gltf","blend","fbx","usd")) { continue }
		if ($carte.Name -notmatch "(?i)diff|alpha|opacity") { continue }
		$r = $carte.Value."1k"
		if ($null -eq $r) { continue }
		foreach ($fmt in @("png")) {
			$f = $r.$fmt
			if ($null -eq $f) { continue }
			$nom = [System.IO.Path]::GetFileName($f.url)
			Invoke-WebRequest -Uri $f.url -OutFile (Join-Path $d $nom)
			$rapport += "$id;$($carte.Name);$nom"
		}
	}
}
$rapport | Set-Content (Join-Path $Sortie "liste.txt")
$rapport
