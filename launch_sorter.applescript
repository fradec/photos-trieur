on chooseFolderWithPrompt(promptText)
	try
		set pickedFolder to choose folder with prompt promptText
		return POSIX path of pickedFolder
	on error number -128
		return "__CANCEL__"
	end try
end chooseFolderWithPrompt

on chooseButton(promptText, buttonList, defaultButton, cancelButton)
	try
		set picked to button returned of (display dialog promptText buttons buttonList default button defaultButton cancel button cancelButton)
		return picked
	on error number -128
		return "__CANCEL__"
	end try
end chooseButton

on readSummaryMessage(pythonBin, summaryPath, modeLabel)
	set pyCode to "import json,sys\nmode=sys.argv[1]\npath=sys.argv[2]\ntry:\n d=json.load(open(path,encoding='utf-8'))\nexcept Exception:\n print(f'{mode} terminee.\\n\\nResume indisponible.')\n raise SystemExit(0)\nprint('\\n'.join([f'{mode} terminee.', '', f\"Fichiers trouves : {d.get('files_found', '?')}\", f\"Fichiers deplacables : {d.get('movable', '?')}\", f\"Fichiers ignores : {d.get('skipped', '?')}\", f\"Erreurs : {d.get('errors', '?')}\", '', f\"Dossier cible : {d.get('output_root', '?')}\", f\"Journal : {d.get('log_path', '?')}\"]))"
	return do shell script quoted form of pythonBin & " -c " & quoted form of pyCode & " " & quoted form of modeLabel & " " & quoted form of summaryPath
end readSummaryMessage

on run
	set appPath to POSIX path of (path to me)
	set appDir to do shell script "/usr/bin/dirname " & quoted form of appPath
	set adjacentSorterPath to appDir & "/photo_sorter.py"
	set sorterPath to ""
	set pythonBin to "/usr/bin/python3"
	
	try
		set sorterPath to POSIX path of (path to resource "photo_sorter.py")
	on error
		try
			do shell script "/usr/bin/test -f " & quoted form of adjacentSorterPath
			set sorterPath to adjacentSorterPath
		on error
			display dialog "Impossible de trouver photo_sorter.py a cote du lanceur." with title "Photos Trieur" buttons {"OK"} default button "OK"
			return
		end try
	end try
	
	set sourceDir to my chooseFolderWithPrompt("Etape 1/4 : choisir le dossier source")
	if sourceDir is "__CANCEL__" then return
	
	set destinationParent to my chooseFolderWithPrompt("Etape 2/4 : choisir le dossier destination (qui contiendra sorted)")
	if destinationParent is "__CANCEL__" then return
	
	set mediaScope to my chooseButton("Etape 3/4 : inclure aussi les videos ?", {"Annuler", "Photos seules", "Photos et videos"}, "Photos seules", "Annuler")
	if mediaScope is "__CANCEL__" then return
	
	set modeChoice to my chooseButton("Etape 4/5 : choisir le mode", {"Annuler", "Previsualiser", "Executer"}, "Previsualiser", "Annuler")
	if modeChoice is "__CANCEL__" then return

	set launchStyle to my chooseButton("Etape 5/5 : mode de lancement", {"Annuler", "Arriere-plan", "Attendre la fin"}, "Arriere-plan", "Annuler")
	if launchStyle is "__CANCEL__" then return
	
	set logDir to POSIX path of (path to library folder from user domain) & "Logs/photos-trieur"
	do shell script "/bin/mkdir -p " & quoted form of logDir
	set runId to do shell script "/bin/date +%Y%m%d-%H%M%S"
	set logFile to logDir & "/photos-trieur-" & runId & ".csv"
	set summaryFile to logDir & "/photos-trieur-" & runId & "-summary.json"
	
	set cmd to quoted form of pythonBin & " " & quoted form of sorterPath & " " & quoted form of sourceDir & " " & quoted form of destinationParent & " --log-file " & quoted form of logFile & " --summary-file " & quoted form of summaryFile
	if mediaScope is "Photos et videos" then
		set cmd to cmd & " --include-videos"
	end if
	if modeChoice is "Executer" then
		set cmd to cmd & " --apply"
	end if

	if launchStyle is "Arriere-plan" then
		set outputLogFile to logDir & "/photos-trieur-" & runId & ".out.log"
		set successOsa to "display notification " & quoted form of ("Traitement termine (" & modeChoice & ").") & " with title " & quoted form of "Photos Trieur"
		set failureOsa to "display notification " & quoted form of ("Traitement echoue (" & modeChoice & "). Voir le journal CSV.") & " with title " & quoted form of "Photos Trieur"
		set workerCmd to cmd & " > " & quoted form of outputLogFile & " 2>&1; exit_code=$?; if [ $exit_code -eq 0 ]; then /usr/bin/osascript -e " & quoted form of successOsa & "; else /usr/bin/osascript -e " & quoted form of failureOsa & "; fi"
		set launchCmd to "/bin/zsh -lc " & quoted form of ("(" & workerCmd & ") </dev/null >/dev/null 2>&1 & echo $!")
		set jobPid to do shell script launchCmd

		set startedChoice to button returned of (display dialog "Traitement lance en arriere-plan (" & modeChoice & ")." & return & return & "PID : " & jobPid & return & "Journal CSV :" & return & logFile & return & return & "Une notification macOS s'affichera a la fin." with title "Photos Trieur" buttons {"OK", "Afficher le journal"} default button "OK")
		if startedChoice is "Afficher le journal" then
			do shell script "/usr/bin/open -R " & quoted form of logFile
		end if
		return
	end if
	
	try
		do shell script cmd
	on error errMsg number errNum
		set failChoice to button returned of (display dialog "Le traitement a echoue (" & modeChoice & ")." & return & return & "Journal :" & return & logFile & return & return & "Detail : " & errMsg with title "Photos Trieur" buttons {"OK", "Afficher le journal"} default button "OK")
		if failChoice is "Afficher le journal" then
			do shell script "/usr/bin/open -R " & quoted form of logFile
		end if
		return
	end try
	
	set modeLabel to modeChoice
	set summaryMessage to my readSummaryMessage(pythonBin, summaryFile, modeLabel)
	set finalChoice to button returned of (display dialog summaryMessage with title "Photos Trieur" buttons {"OK", "Afficher le journal"} default button "OK")
	if finalChoice is "Afficher le journal" then
		do shell script "/usr/bin/open -R " & quoted form of logFile
	end if
end run
