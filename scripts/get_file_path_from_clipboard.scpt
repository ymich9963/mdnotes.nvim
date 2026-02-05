tell application "Finder"
	set theSelection to the clipboard as «class furl»
	set thePath to POSIX path of theSelection
	return thePath
end tell
