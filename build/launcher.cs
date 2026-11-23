// FOHstick.exe – small launcher for the PowerShell UI (Windows 10/11).
// (c) 2026 fristik.eu · apps@fristik.eu · https://fristik.eu
using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;
using System.Windows.Forms;

[assembly: AssemblyTitle("FOHstick")]
[assembly: AssemblyProduct("FOHstick")]
[assembly: AssemblyCompany("fristik.eu")]
[assembly: AssemblyCopyright("© 2026 fristik.eu")]
[assembly: AssemblyVersion("@@VERSION@@.0")]
[assembly: AssemblyFileVersion("@@VERSION@@.0")]

static class Launcher {
    [STAThread]
    static int Main() {
        try {
            string dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "fristik.eu");
            Directory.CreateDirectory(dir);
            string script = Path.Combine(dir, "FOHstick-@@VERSION@@.ps1");
            using (Stream s = Assembly.GetExecutingAssembly().GetManifestResourceStream("FOHstick.ps1"))
            using (StreamReader r = new StreamReader(s, Encoding.UTF8)) {
                File.WriteAllText(script, r.ReadToEnd(), new UTF8Encoding(true));
            }
            ProcessStartInfo psi = new ProcessStartInfo();
            psi.FileName = Path.Combine(Environment.SystemDirectory, @"WindowsPowerShell\v1.0\powershell.exe");
            psi.Arguments = "-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + script + "\"";
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            psi.EnvironmentVariables["K48"] = Assembly.GetExecutingAssembly().Location;
            Process.Start(psi);
            return 0;
        } catch (Exception e) {
            MessageBox.Show("FOHstick could not start:\n" + e.Message, "FOHstick", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }
}
