using System.Diagnostics;
using System.IO;

namespace MotW.Shared.Utils
{
    /// <summary>
    /// Standard logging levels based on RFC 5424 (Syslog Protocol)
    /// </summary>
    public enum LogLevel
    {
        Emergency = 0,  // System unusable
        Alert = 1,      // Action must be taken immediately
        Critical = 2,   // Critical conditions
        Error = 3,      // Error conditions
        Warning = 4,    // Warning conditions
        Notice = 5,     // Normal but significant
        Info = 6,       // Informational messages
        Debug = 7       // Debug-level messages
    }

    public static class Logger
    {
        private static readonly object _lockObj = new();
        private static readonly string BaseDir =
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "MotW");

        private static readonly string LogPath = Path.Combine(BaseDir, "motw.log");
        private const long MaxLogSizeBytes = 10 * 1024 * 1024; // 10 MB

        // Configurable minimum log level (default: Info)
        public static LogLevel MinimumLevel { get; set; } = LogLevel.Info;

        static Logger()
        {
            try
            { Directory.CreateDirectory(BaseDir); }
            catch { /* ignore */ }
        }

        // RFC 5424 standard methods
        public static void Emergency(string message) => Write(LogLevel.Emergency, message);
        public static void Alert(string message) => Write(LogLevel.Alert, message);
        public static void Critical(string message) => Write(LogLevel.Critical, message);
        public static void Error(string message) => Write(LogLevel.Error, message);
        public static void Warning(string message) => Write(LogLevel.Warning, message);
        public static void Notice(string message) => Write(LogLevel.Notice, message);
        public static void Info(string message) => Write(LogLevel.Info, message);
        public static void Debug(string message) => Write(LogLevel.Debug, message);

        // Backwards compatibility aliases
        public static void Warn(string message) => Warning(message);

        private static void Write(LogLevel level, string message)
        {
            // Check if this message meets the minimum log level threshold
            if (level > MinimumLevel)
                return;

            lock (_lockObj)
            {
                try
                {
                    if (File.Exists(LogPath) && new FileInfo(LogPath).Length > MaxLogSizeBytes)
                    {
                        RotateLog();
                    }

                    var sanitizedMessage = SanitizeLogMessage(message);
                    var levelName = GetLevelName(level);
                    var line = $"{DateTimeOffset.Now:O} [{levelName}] {sanitizedMessage}";
                    File.AppendAllText(LogPath, line + Environment.NewLine);
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"Logger failed: {ex.Message} | Original: [{GetLevelName(level)}] {message}");
                }
            }
        }

        private static string GetLevelName(LogLevel level)
        {
            return level switch
            {
                LogLevel.Emergency => "EMERG",
                LogLevel.Alert => "ALERT",
                LogLevel.Critical => "CRIT",
                LogLevel.Error => "ERROR",
                LogLevel.Warning => "WARN",
                LogLevel.Notice => "NOTICE",
                LogLevel.Info => "INFO",
                LogLevel.Debug => "DEBUG",
                _ => level.ToString().ToUpper()
            };
        }

        private static void RotateLog()
        {
            try
            {
                var archivePath = Path.Combine(BaseDir, $"motw.{DateTime.Now:yyyyMMdd-HHmmss}.log");
                File.Move(LogPath, archivePath);

                var archives = Directory.GetFiles(BaseDir, "motw.*.log")
                    .OrderByDescending(f => f)
                    .Skip(5)
                    .ToList();

                foreach (var old in archives)
                {
                    try
                    { File.Delete(old); }
                    catch { /* best effort */ }
                }
            }
            catch
            {
                try
                { File.WriteAllText(LogPath, string.Empty); }
                catch { /* best effort */ }
            }
        }

        private static string SanitizeLogMessage(string message)
        {
            if (string.IsNullOrEmpty(message))
                return string.Empty;

            return message
                .Replace("\r", "\\r")
                .Replace("\n", "\\n")
                .Replace("\t", "\\t");
        }

        public static string LogFilePath => LogPath;
        public static string LogFolder => BaseDir;
    }
}
