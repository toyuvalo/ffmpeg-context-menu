' launcher.vbs — Collects ALL selected files from Explorer via COM, then launches converter
' Windows launches one wscript per file, but we only need the first instance.
' The first instance grabs the full selection from the Explorer window via Shell.Application.
' Usage: wscript.exe launcher.vbs "%1"

Dim fso, wshShell
Set fso = CreateObject("Scripting.FileSystemObject")
Set wshShell = CreateObject("WScript.Shell")

' Use a lock file so only the first instance does the work
Dim tempDir, lockFile
tempDir = wshShell.ExpandEnvironmentStrings("%TEMP%")
lockFile = tempDir & "\ffmpeg_convert.lock"

' Try to create lock — first instance wins, rest exit
On Error Resume Next
If fso.FileExists(lockFile) Then
    ' Check if lock is stale (older than 5 seconds)
    Dim lockAge
    lockAge = DateDiff("s", fso.GetFile(lockFile).DateLastModified, Now)
    If lockAge < 5 Then
        ' Another instance is already handling this
        WScript.Quit
    End If
End If

Dim lockHandle
Set lockHandle = fso.CreateTextFile(lockFile, True)
If Err.Number <> 0 Then
    ' Another instance beat us
    WScript.Quit
End If
lockHandle.Close
On Error GoTo 0

' Small delay to let Explorer finish launching all instances
WScript.Sleep 400

' Get selected files from the active Explorer window via COM
Dim shellApp, wnd, selectedItems
Dim files
Set files = CreateObject("Scripting.Dictionary")

On Error Resume Next
Set shellApp = CreateObject("Shell.Application")
For Each wnd In shellApp.Windows
    If InStr(1, TypeName(wnd.Document), "ShellFolderView", vbTextCompare) > 0 Then
        Set selectedItems = wnd.Document.SelectedItems
        If Not selectedItems Is Nothing Then
            If selectedItems.Count > 0 Then
                Dim item
                For Each item In selectedItems
                    If Not files.Exists(item.Path) Then
                        files.Add item.Path, True
                    End If
                Next
                ' Only use the first Explorer window with a selection
                If files.Count > 0 Then Exit For
            End If
        End If
    End If
Next
On Error GoTo 0

' Fallback: if COM didn't find anything, use the %1 argument
If files.Count = 0 And WScript.Arguments.Count > 0 Then
    Dim argPath
    argPath = WScript.Arguments(0)
    If argPath <> "" And fso.FileExists(argPath) Then
        files.Add argPath, True
    End If
End If

' Clean up lock
On Error Resume Next
fso.DeleteFile lockFile, True
On Error GoTo 0

If files.Count = 0 Then WScript.Quit

' Write file list
Dim collectFile, cf, key
collectFile = tempDir & "\ffmpeg_convert_batch.txt"
Set cf = fso.CreateTextFile(collectFile, True)
For Each key In files.Keys
    cf.WriteLine key
Next
cf.Close

' Launch PowerShell converter
Dim scriptPath, cmd
scriptPath = fso.GetParentFolderName(WScript.ScriptFullName) & "\ffmpeg-convert.ps1"
cmd = "powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File """ & scriptPath & """ -ListFile """ & collectFile & """"
wshShell.Run cmd, 0, False
