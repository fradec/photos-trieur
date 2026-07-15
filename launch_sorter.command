#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PYTHON_BIN=${PYTHON_BIN:-python3}
APP_SCRIPT="$SCRIPT_DIR/photo_sorter.py"

choose_folder() {
  local prompt="$1"
  osascript <<OSA
POSIX path of (choose folder with prompt "$prompt")
OSA
}

choose_button() {
  local prompt="$1"
  local default_button="$2"
  shift 2
  local buttons=()
  local button
  for button in "$@"; do
    buttons+=("\"$button\"")
  done
  local joined_buttons
  joined_buttons=$(IFS=, ; print -r -- "${buttons[*]}")
  osascript <<OSA
button returned of (display dialog "$prompt" buttons {$joined_buttons} default button "$default_button")
OSA
}

show_dialog() {
  local title="$1"
  local message="$2"
  osascript <<OSA
 display dialog "$message" with title "$title" buttons {"OK"} default button "OK"
OSA
}

mkdir -p "$HOME/Library/Logs/photos-trieur"
LOG_FILE="$HOME/Library/Logs/photos-trieur/photos-trieur-$(date +%Y%m%d-%H%M%S).csv"

print
print "Photos Trieur"
print "=================="
print

SOURCE_DIR=$(choose_folder "Choisir le dossier source a analyser")
DESTINATION_PARENT=$(choose_folder "Choisir le dossier qui recevra le dossier 'photos triees'")
MODE=$(choose_button "Choisir le mode d'execution" "Previsualiser" "Previsualiser" "Deplacer")
MEDIA_SCOPE=$(choose_button "Faut-il inclure aussi les videos ?" "Photos seules" "Photos seules" "Photos et videos")

COMMAND=("$PYTHON_BIN" "$APP_SCRIPT" "$SOURCE_DIR" "$DESTINATION_PARENT" "--log-file" "$LOG_FILE")
if [[ "$MODE" == "Deplacer" ]]; then
  COMMAND+=("--apply")
fi
if [[ "$MEDIA_SCOPE" == "Photos et videos" ]]; then
  COMMAND+=("--include-videos")
fi

print "Source        : $SOURCE_DIR"
print "Destination   : $DESTINATION_PARENT/photos triees"
print "Mode          : $MODE"
print "Journal       : $LOG_FILE"
print

"${COMMAND[@]}"
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
  show_dialog "Photos Trieur" "Traitement termine.\n\nJournal:\n$LOG_FILE"
else
  show_dialog "Photos Trieur" "Le traitement a echoue.\n\nConsulter le journal ou la sortie Terminal.\n\nJournal:\n$LOG_FILE"
fi

print
read -r "?Appuyer sur Entree pour fermer..."
