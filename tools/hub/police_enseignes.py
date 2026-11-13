"""Fabrique la police des enseignes du hub (Noto Sans JP Bold, licence OFL), réduite
aux caractères utiles pour rester légère (~300 Ko au lieu de 9 Mo).

Garde : alphabet latin et accents, ponctuation, flèches, tous les hiragana et katakana,
et les kanji présents dans scripts/monde/hikari_bay.gd (+ une petite liste en réserve).
Après avoir ajouté un nouveau kanji dans une enseigne, relancer :
    pip install fonttools
    python tools/hub/police_enseignes.py chemin/vers/NotoSansJP[wght].ttf
(la police complète se télécharge sur https://github.com/google/fonts/tree/main/ofl/notosansjp)
"""
import sys
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

RACINE = Path(__file__).resolve().parents[2]
SCRIPT = RACINE / "game/scripts/monde/hikari_bay.gd"
SORTIE = RACINE / "game/assets/polices/NotoSansJP-Bold-hub.ttf"
RESERVE = "光夜市職人街博物館海辺寿司喫茶旭駅工事中住宅閉鎖本日営業時間入口出口東西南北警察病院駐車場禁煙"

texte = SCRIPT.read_text(encoding="utf-8")
kanji = {ord(c) for c in texte + RESERVE if ord(c) > 0x2E80}
plages = [(0x20, 0x7F), (0xA0, 0x180), (0x2000, 0x2070), (0x2190, 0x21A0), (0x3000, 0x3100), (0xFF01, 0xFF5F)]
codes = set(kanji)
for debut, fin in plages:
    codes.update(range(debut, fin))

police = instancer.instantiateVariableFont(TTFont(sys.argv[1]), {"wght": 700})
options = subset.Options()
options.layout_features = ["*"]
options.name_IDs = ["*"]
sous_ensemble = subset.Subsetter(options)
sous_ensemble.populate(unicodes=sorted(codes))
sous_ensemble.subset(police)
police.save(SORTIE)
print(f"{SORTIE} : {len(kanji)} kanji/kana, {SORTIE.stat().st_size // 1024} Ko")
