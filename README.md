# Photos Trieur

Petit utilitaire macOS pour trier un gros stock de photos sans interface lourde.

Le projet repose sur deux fichiers utiles:
- `photo_sorter.py`: moteur de tri
- `launch_sorter.applescript`: source du lanceur macOS sans Terminal

## Ce que fait l'outil

- choix visuel du dossier source
- choix visuel du dossier destination
- choix du nom du dossier cible (par defaut `sorted`)
- scan recursif automatique des sous-dossiers
- creation ou reutilisation du dossier cible
- creation de sous-dossiers `YYYY/YYYY-MM`
- deplacement uniquement si la date est sans ambiguite
- renommage uniforme des fichiers deplaces en `YYYY-MM-DD_HH-MM-SS.ext`
- conservation sur place des fichiers douteux
- journal CSV local pour savoir ce qui a ete fait et relancer sans risque

## Regles de tri

- priorite aux metadonnees EXIF quand elles sont coherentes
- repli sur le nom du fichier quand il contient une date exploitable
- en cas de conflit ou de doute, le fichier est laisse en place

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

Puis le mode de lancement:
- `Arriere-plan` (recommande, non bloquant)
- `Attendre la fin` (bloquant, avec resume immediat)

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
- le dossier `sorted` est ignore pendant les scans suivants
- le journal CSV garde une trace de chaque decision

## Conseil pratique

Pour de meilleures performances, choisir un dossier destination situe sur le meme volume que la source.
