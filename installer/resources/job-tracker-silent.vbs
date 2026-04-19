' job-tracker-silent.vbs — launch Job Tracker without a console window.
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

installDir = fso.GetParentFolderName(WScript.ScriptFullName)
pythonw = installDir & "\python\pythonw.exe"
runScript = installDir & "\app\run.py"

' Point the app at %APPDATA%\JobTracker for config + data.
shell.Environment("PROCESS")("JOBTRACKER_DATA_DIR") = shell.ExpandEnvironmentStrings("%APPDATA%\JobTracker")

shell.CurrentDirectory = installDir & "\app"
shell.Run """" & pythonw & """ """ & runScript & """ --no-browser", 0, False

' Open the browser to the app.
WScript.Sleep 1500
shell.Run "http://127.0.0.1:5000", 1, False
