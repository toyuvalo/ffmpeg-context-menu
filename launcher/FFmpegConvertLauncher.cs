// FFmpegConvertLauncher.cs -- FFmpegConvert.exe, the right-click entry point (v1.4.0)
// Replaces launcher.vbs. A wscript-run VBScript that starts a hidden PowerShell
// window is a classic malware chain, and antivirus flags installers built on it.
// VBScript is also being removed from Windows. Same logic as the VBS (v2.1.0):
//   1. Explorer starts one instance per selected file; a lock file lets only the
//      first one do the work.
//   2. Find the Explorer window whose selection holds the right-clicked path (%1)
//      and collect ALL its selected files (multi-select).
//   3. Write the list as UTF-8 and start ffmpeg-convert.ps1 with no console window.
//   --folder "<dir>" (folder menu) skips 1-3 and passes the folder as -Path.
// Same code as Doc Convert's DocConvertLauncher.cs. Build: build.cmd.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;
using System.Threading;

[assembly: AssemblyTitle("FFmpeg Convert")]
[assembly: AssemblyDescription("FFmpeg Convert right-click media converter")]
[assembly: AssemblyProduct("FFmpeg Convert")]
[assembly: AssemblyCompany("DVLCE")]
[assembly: AssemblyCopyright("MIT with Commons Clause")]
[assembly: AssemblyVersion("1.4.0.0")]
[assembly: AssemblyFileVersion("1.4.0.0")]

static class FFmpegConvertLauncher
{
    [STAThread]
    static int Main(string[] args)
    {
        // Folder menu: FFmpegConvert.exe --folder "<dir>" converts every file in it.
        if (args.Length > 1 && args[0] == "--folder")
        {
            // Explorer passes a drive root as "C:\", and the \" on the command line
            // arrives here as C:" -- undo that before checking the folder.
            string dir = args[1].TrimEnd('"');
            if (dir.EndsWith(":")) dir += "\\";
            if (Directory.Exists(dir)) StartScript("-Path \"" + QuotableDir(dir) + "\"");
            return 0;
        }

        string rightClicked = args.Length > 0 ? args[0] : "";
        string tempDir = Path.GetTempPath();
        string lockFile = Path.Combine(tempDir, "ffmpeg_convert.lock");

        try
        {
            if (File.Exists(lockFile) &&
                (DateTime.Now - File.GetLastWriteTime(lockFile)).TotalSeconds < 5)
                return 0;
            File.WriteAllText(lockFile, "");
        }
        catch { return 0; }

        // Let Explorer finish launching all instances.
        Thread.Sleep(400);

        var files = new List<string>();
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        try { CollectFromExplorer(rightClicked, files, seen); } catch { }

        // Fallback: the right-clicked file alone if no window matched.
        if (files.Count == 0 && rightClicked != "" && File.Exists(rightClicked))
            files.Add(rightClicked);

        try { File.Delete(lockFile); } catch { }

        if (files.Count == 0) return 0;

        string listFile = Path.Combine(tempDir, "ffmpeg_convert_batch.txt");
        File.WriteAllLines(listFile, files.ToArray(), new UTF8Encoding(true));

        StartScript("-ListFile \"" + listFile + "\"");
        return 0;
    }

    static void StartScript(string scriptArgs)
    {
        string script = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "ffmpeg-convert.ps1");
        // -ExecutionPolicy Bypass stays: the Windows client default policy
        // (Restricted) refuses every script, signed or not.
        var psi = new ProcessStartInfo("powershell.exe",
            "-NoProfile -ExecutionPolicy Bypass -File \"" + script + "\" " + scriptArgs);
        psi.UseShellExecute = false;
        psi.CreateNoWindow = true;
        Process.Start(psi);
    }

    // A trailing backslash before the closing quote ("C:\Music\") escapes the
    // quote on the command line. Drop it; a drive root becomes "C:\.".
    static string QuotableDir(string dir)
    {
        string d = dir.TrimEnd('\\');
        return d.EndsWith(":") ? d + "\\." : d;
    }

    static void CollectFromExplorer(string rightClicked, List<string> files, HashSet<string> seen)
    {
        Type shellType = Type.GetTypeFromProgID("Shell.Application");
        dynamic shell = Activator.CreateInstance(shellType);
        foreach (dynamic wnd in shell.Windows())
        {
            dynamic selected;
            try
            {
                if (wnd == null) continue;
                dynamic doc = wnd.Document;
                if (doc == null) continue;
                selected = doc.SelectedItems();
            }
            catch { continue; }   // not a folder view (e.g. an IE window)
            if (selected == null || selected.Count == 0) continue;

            bool match = false;
            foreach (dynamic item in selected)
            {
                if (string.Equals((string)item.Path, rightClicked, StringComparison.OrdinalIgnoreCase))
                { match = true; break; }
            }
            if (!match) continue;

            foreach (dynamic item in selected)
            {
                string p = item.Path;
                if (seen.Add(p)) files.Add(p);
            }
            return;
        }
    }
}
