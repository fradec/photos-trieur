# Photos Trieur

Petit utilitaire macOS pour trier un gros stock de photos sans interface lourde.

Le projet repose sur deux fichiers utiles:
- `photo_sorter.py`: moteur de tri
- `launch_sorter.applescript`: source du lanceur macOS sans Terminal

## Ce que fait l'outil

- choix visuel du dossier source
- choix visuel du dossier cible final (existant ou nouveau)
- scan recursif automatique des sous-dossiers
- creation ou reutilisation du dossier cible
- creation de sous-dossiers `YYYY/YYYY-MM`
- deplacement uniquement si la date est sans ambiguite
- renommage uniforme des fichiers deplaces en `YYYY-MM-DD_HH-MM-SS[-fff]__hash8.ext`
- centralisation des fichiers non deplacables dans `skip/` (dossier voisin de la sortie cible)
- journal CSV local pour savoir ce qui a ete fait et relancer sans risque

## Regles de tri

- priorite aux metadonnees EXIF quand elles sont coherentes
- repli sur le nom du fichier quand il contient une date exploitable
- en cas de conflit ou de doute, le fichier est deplace vers `skip/` dans le sous-dossier correspondant

## Dossier skip

Les fichiers non deplacables sont envoyes dans un dossier `skip` place au meme niveau que le dossier cible choisi.

Exemple:
- cible: `/Volumes/DISK/Tri`
- non deplacables: `/Volumes/DISK/skip/...`

Sous-dossiers de `skip` (raisons metier):
- `metadata_conflict`: les metadata donnent plusieurs mois differents
- `filename_conflict`: le nom du fichier contient plusieurs mois differents
- `metadata_filename_mismatch`: le mois issu des metadata ne correspond pas au mois lu dans le nom
- `no_reliable_date`: impossible de determiner un mois fiable (metadata et nom insuffisants)

Note: ces fichiers gardent leur nom d'origine.

## Prerequis

Verifier `exiftool`:

```bash
brew install exiftool
```

## Utilisation

Compiler puis lancer l'application macOS sans Terminal:

```bash
cd /Users/nono/code/nono/photos-trieur
./build_app.sh
open "Photos Trieur.app"
```

Dans le lanceur, vous choisissez explicitement le mode:
- `Previsualiser` (dry-run)
- `Executer` (deplacement reel)

Avec l'option videos activee, les extensions suivantes sont prises en charge:
- `.mov`, `.mp4`, `.m4v`, `.avi`, `.mts`, `.flv`, `.webm`, `.mpg`

Le traitement est lance en arriere-plan pour ne pas bloquer les autres applications.

Le journal est ecrit par defaut dans:

```text
~/Library/Logs/photos-trieur/
```

## Ligne de commande

Le moteur peut aussi etre lance sans le lanceur graphique:

```bash
python3 photo_sorter.py "/Volumes/MON_DISQUE/Photos" "/Volumes/MON_DISQUE" --log-file ~/Library/Logs/photos-trieur/manuel.csv
```

Vous pouvez changer le nom du dossier cible:

```bash
python3 photo_sorter.py "/Volumes/MON_DISQUE/Photos" "/Volumes/MON_DISQUE" --output-folder-name "mes-photos-triees"
```

Ajouter `--apply` pour deplacer reellement les fichiers.

## Licence

Ce projet est distribue sous The Unlicense (domaine public).

## Reprise

Le traitement est naturellement relancable:
- les fichiers deja deplaces ne sont plus dans la source
- le dossier cible et le dossier `skip` sont ignores pendant les scans suivants
- le journal CSV garde une trace de chaque decision

## Conseil pratique

Pour de meilleures performances, choisir un dossier destination situe sur le meme volume que la source.
