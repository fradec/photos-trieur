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
	
	set outputFolderPath to my chooseFolderWithPrompt("Etape 2/4 : choisir le dossier cible final (existant ou nouveau)")
	if outputFolderPath is "__CANCEL__" then return
	set destinationParent to do shell script "/usr/bin/dirname " & quoted form of outputFolderPath
	set outputFolderName to do shell script "/usr/bin/basename " & quoted form of outputFolderPath
	
	set mediaScope to my chooseButton("Etape 3/4 : inclure aussi les videos ?", {"Annuler", "Photos seules", "Photos et videos"}, "Photos seules", "Annuler")
	if mediaScope is "__CANCEL__" then return
	
	set modeChoice to my chooseButton("Etape 4/4 : choisir le mode", {"Annuler", "Previsualiser", "Executer"}, "Previsualiser", "Annuler")
	if modeChoice is "__CANCEL__" then return
	
	set logDir to POSIX path of (path to library folder from user domain) & "Logs/photos-trieur"
	do shell script "/bin/mkdir -p " & quoted form of logDir
	set runId to do shell script "/bin/date +%Y%m%d-%H%M%S"
	set logFile to logDir & "/photos-trieur-" & runId & ".csv"
	set summaryFile to logDir & "/photos-trieur-" & runId & "-summary.json"
	
	set cmd to quoted form of pythonBin & " " & quoted form of sorterPath & " " & quoted form of sourceDir & " " & quoted form of destinationParent & " --log-file " & quoted form of logFile & " --summary-file " & quoted form of summaryFile & " --output-folder-name " & quoted form of outputFolderName
	if mediaScope is "Photos et videos" then
		set cmd to cmd & " --include-videos"
	end if
	if modeChoice is "Executer" then
		set cmd to cmd & " --apply"
	end if

	set outputLogFile to logDir & "/photos-trieur-" & runId & ".out.log"
	set notifySuccess to "display notification \"Traitement termine (" & modeChoice & ").\" with title \"Photos Trieur\""
	set notifyFailure to "display notification \"Traitement echoue (" & modeChoice & "). Voir le journal.\" with title \"Photos Trieur\""
	set workerCmd to cmd & " > " & quoted form of outputLogFile & " 2>&1; exit_code=$?; if [ \"$exit_code\" -eq 0 ]; then /usr/bin/osascript -e " & quoted form of notifySuccess & "; else /usr/bin/osascript -e " & quoted form of notifyFailure & "; fi; /usr/bin/open " & quoted form of logDir
	set launchCmd to "/bin/zsh -lc " & quoted form of ("nohup sh -c " & quoted form of workerCmd & " </dev/null >/dev/null 2>&1 & echo $!")
	do shell script launchCmd
	return
end run
