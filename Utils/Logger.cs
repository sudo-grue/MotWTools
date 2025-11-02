using System.IO;

namespace MotWUnblocker.Utils
{
    public static class Logger
    {
        private static readonly string BaseDir =
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "MotWUnblocker");

        private static readonly string LogPath = Path.Combine(BaseDir, "unblocker.log");

        static Logger()
        {
            try { Directory.CreateDirectory(BaseDir); } catch { /* ignore */ }
        }

        public static void Info(string message) => Write("INFO", message);
        public static void Warn(string message) => Write("WARN", message);
        public static void Error(string message) => Write("ERROR", message);

        private static void Write(string level, string message)
        {
            try
            {
                var line = $"{DateTimeOffset.Now:O} [{level}] {message}";
                File.AppendAllText(LogPath, line + Environment.NewLine);
            }
            catch { /* best-effort logging */ }
        }

        public static string LogFilePath => LogPath;
        public static string LogFolder => BaseDir;
    }
}
