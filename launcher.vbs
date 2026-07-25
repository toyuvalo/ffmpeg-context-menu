' launcher.vbs v2.1.0 — Collects ALL selected files from Explorer via COM, then launches converter
' Bug fix 2026-07-25: the file list was written with FileSystemObject's default
' ASCII/ANSI encoding while ffmpeg-convert.ps1 read it back as UTF-8. Any name
' with a non-ASCII character (smart quote ’, accent, en-dash — normal in track
' titles) came back with a replacement character, the path stopped resolving,
' and the file was silently dropped from the batch. Now written as UTF-8 via
' ADODB.Stream, which every consumer of this list already reads correctly.
' Bug fix 2026-05-19: previously iterated all Explorer windows and grabbed the
' SelectedItems of the FIRST one with any selection — which could be the wrong
' window if the user had another Explorer window open. Now matches the right-
' clicked path (%1) against each window's selection and uses the window that
' actually contains it.
' Usage: wscript.exe launcher.vbs "%1"

Dim fso, wshShell
Set fso = CreateObject("Scripting.FileSystemObject")
Set wshShell = CreateObject("WScript.Shell")

Dim rightClickedPath
If WScript.Arguments.Count > 0 Then
    rightClickedPath = WScript.Arguments(0)
Else
    rightClickedPath = ""
End If

' Use a lock file so only the first instance does the work
Dim tempDir, lockFile
tempDir = wshShell.ExpandEnvironmentStrings("%TEMP%")
lockFile = tempDir & "\ffmpeg_convert.lock"

On Error Resume Next
If fso.FileExists(lockFile) Then
    Dim lockAge
    lockAge = DateDiff("s", fso.GetFile(lockFile).DateLastModified, Now)
    If lockAge < 5 Then
        WScript.Quit
    End If
End If

Dim lockHandle
Set lockHandle = fso.CreateTextFile(lockFile, True)
If Err.Number <> 0 Then
    WScript.Quit
End If
lockHandle.Close
On Error GoTo 0

' Small delay to let Explorer finish launching all wscript instances
WScript.Sleep 400

' Iterate Explorer windows; find the one whose selection contains the
' right-clicked path. Only that window's selection gets used.
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
                ' Check: is the right-clicked path in THIS window's selection?
                Dim item, matchFound
                matchFound = False
                For Each item In selectedItems
                    If StrComp(item.Path, rightClickedPath, vbTextCompare) = 0 Then
                        matchFound = True
                        Exit For
                    End If
                Next
                If matchFound Then
                    For Each item In selectedItems
                        If Not files.Exists(item.Path) Then
                            files.Add item.Path, True
                        End If
                    Next
                    Exit For
                End If
            End If
        End If
    End If
Next
On Error GoTo 0

' Fallback: if no window matched (e.g. file was right-clicked from a search-
' results view or Desktop), just convert the single %1 file.
If files.Count = 0 And rightClickedPath <> "" Then
    If fso.FileExists(rightClickedPath) Then
        files.Add rightClickedPath, True
    End If
End If

' Clean up lock
On Error Resume Next
fso.DeleteFile lockFile, True
On Error GoTo 0

If files.Count = 0 Then WScript.Quit

' Write file list as UTF-8 (with BOM) so non-ASCII file names survive the
' hand-off. ADODB.Stream is the only way to control the encoding from VBS.
Dim collectFile, key, stream, wroteUtf8
collectFile = tempDir & "\ffmpeg_convert_batch.txt"
wroteUtf8 = False

On Error Resume Next
Set stream = CreateObject("ADODB.Stream")
If Err.Number = 0 Then
    stream.Type = 2                 ' adTypeText
    stream.Charset = "utf-8"
    stream.Open
    For Each key In files.Keys
        stream.WriteText key & vbCrLf
    Next
    stream.SaveToFile collectFile, 2 ' adSaveCreateOverWrite
    stream.Close
    If Err.Number = 0 Then wroteUtf8 = True
End If
Err.Clear
On Error GoTo 0

' Fallback if ADODB is unavailable — ASCII-named files still convert.
If Not wroteUtf8 Then
    Dim cf
    Set cf = fso.CreateTextFile(collectFile, True)
    For Each key In files.Keys
        cf.WriteLine key
    Next
    cf.Close
End If

' Launch PowerShell converter
Dim scriptPath, cmd
scriptPath = fso.GetParentFolderName(WScript.ScriptFullName) & "\ffmpeg-convert.ps1"
cmd = "powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File """ & scriptPath & """ -ListFile """ & collectFile & """"
wshShell.Run cmd, 0, False
