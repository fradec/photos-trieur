# Photos Trieur

Petit utilitaire macOS pour trier un gros stock de photos sans interface lourde.

Le projet repose sur deux fichiers utiles:
- `photo_sorter.py`: moteur de tri
- `launch_sorter.command`: lanceur macOS avec selection visuelle des dossiers

## Ce que fait l'outil

- choix visuel du dossier source
- choix visuel du dossier destination
- scan recursif automatique des sous-dossiers
- creation ou reutilisation d'un dossier `sorted`
- creation de sous-dossiers `YYYY-MM`
- deplacement uniquement si la date est sans ambiguite
- conservation sur place des fichiers douteux
- journal CSV local pour savoir ce qui a ete fait et relancer sans risque

## Regles de tri

- priorite aux metadonnees EXIF quand elles sont coherentes
- repli sur le nom du fichier quand il contient une date exploitable
- en cas de conflit ou de doute, le fichier est laisse en place

## Pourquoi c'est simple

- pas de framework web
- pas de base de donnees
- pas de dependance Python externe
- seulement `python3`, `osascript` et `exiftool`

## Prerequis

Verifier `exiftool`:

```bash
brew install exiftool
```

## Utilisation

Double-cliquer sur `launch_sorter.command` dans le Finder ou lancer:

```bash
cd /Users/nono/code/nono/photos-trieur
chmod +x launch_sorter.command
./launch_sorter.command
```

Le journal est ecrit par defaut dans:

```text
~/Library/Logs/photos-trieur/
```

## Ligne de commande

Le moteur peut aussi etre lance sans le lanceur graphique:

```bash
python3 photo_sorter.py "/Volumes/MON_DISQUE/Photos" "/Volumes/MON_DISQUE" --log-file ~/Library/Logs/photos-trieur/manuel.csv
```

Ajouter `--apply` pour deplacer reellement les fichiers.

## Reprise

Le traitement est naturellement relancable:
- les fichiers deja deplaces ne sont plus dans la source
- le dossier `sorted` est ignore pendant les scans suivants
- le journal CSV garde une trace de chaque decision

## Conseil pratique

Pour de meilleures performances, choisir un dossier destination situe sur le meme volume que la source.
