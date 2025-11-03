using System.Diagnostics;
using System.IO;

namespace MotWUnblocker.Utils
{
    public static class Logger
    {
        private static readonly object _lockObj = new();
        private static readonly string BaseDir =
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "MotWUnblocker");

        private static readonly string LogPath = Path.Combine(BaseDir, "unblocker.log");
        private const long MaxLogSizeBytes = 10 * 1024 * 1024; // 10 MB

        static Logger()
        {
            try { Directory.CreateDirectory(BaseDir); } catch { /* ignore */ }
        }

        public static void Info(string message) => Write("INFO", message);
        public static void Warn(string message) => Write("WARN", message);
        public static void Error(string message) => Write("ERROR", message);

        private static void Write(string level, string message)
        {
            lock (_lockObj)
            {
                try
                {
                    // Rotate log if it's too large
                    if (File.Exists(LogPath) && new FileInfo(LogPath).Length > MaxLogSizeBytes)
                    {
                        RotateLog();
                    }

                    var sanitizedMessage = SanitizeLogMessage(message);
                    var line = $"{DateTimeOffset.Now:O} [{level}] {sanitizedMessage}";
                    File.AppendAllText(LogPath, line + Environment.NewLine);
                }
                catch (Exception ex)
                {
                    // Fallback to debug output if file logging fails
                    Debug.WriteLine($"Logger failed: {ex.Message} | Original: [{level}] {message}");
                }
            }
        }

        private static void RotateLog()
        {
            try
            {
                var archivePath = Path.Combine(BaseDir, $"unblocker.{DateTime.Now:yyyyMMdd-HHmmss}.log");
                File.Move(LogPath, archivePath);

                // Clean up old archives (keep only last 5)
                var archives = Directory.GetFiles(BaseDir, "unblocker.*.log")
                    .OrderByDescending(f => f)
                    .Skip(5)
                    .ToList();

                foreach (var old in archives)
                {
                    try { File.Delete(old); } catch { /* best effort */ }
                }
            }
            catch
            {
                // If rotation fails, just truncate the current log
                try { File.WriteAllText(LogPath, string.Empty); } catch { /* best effort */ }
            }
        }

        private static string SanitizeLogMessage(string message)
        {
            if (string.IsNullOrEmpty(message))
                return string.Empty;

            // Escape newlines and carriage returns to prevent log injection
            return message
                .Replace("\r", "\\r")
                .Replace("\n", "\\n")
                .Replace("\t", "\\t");
        }

        public static string LogFilePath => LogPath;
        public static string LogFolder => BaseDir;
    }
}
