using MotWUnblocker.Utils;
using System.IO;

namespace MotWUnblocker.Services
{
    public static class MotWService
    {
        private const string ZoneIdentifierStream = ":Zone.Identifier";
        private static string ZoneStream(string path) => path + ZoneIdentifierStream;

        public static bool HasMotW(string path)
        {
            if (string.IsNullOrWhiteSpace(path))
                return false;

            try
            {
                if (!File.Exists(path))
                    return false;

                return File.Exists(ZoneStream(path));
            }
            catch (UnauthorizedAccessException ex)
            {
                Logger.Warn($"Access denied checking MotW: {path} - {ex.Message}");
                return false;
            }
            catch (IOException ex)
            {
                Logger.Warn($"IO error checking MotW: {path} - {ex.Message}");
                return false;
            }
            catch (Exception ex)
            {
                Logger.Error($"Unexpected error checking MotW: {path} - {ex.Message}");
                return false;
            }
        }

        public static bool Unblock(string path, out string? error)
        {
            error = null;

            if (string.IsNullOrWhiteSpace(path))
            {
                error = "File path cannot be empty.";
                return false;
            }

            try
            {
                if (!File.Exists(path))
                {
                    error = "File does not exist.";
                    Logger.Warn($"Unblock failed - file not found: {path}");
                    return false;
                }

                var zoneStream = ZoneStream(path);
                if (File.Exists(zoneStream))
                {
                    File.Delete(zoneStream);
                    Logger.Info($"Successfully unblocked: {path}");
                }
                else
                {
                    Logger.Info($"No MotW to remove: {path}");
                }

                return true;
            }
            catch (UnauthorizedAccessException ex)
            {
                error = $"Access denied: {ex.Message}";
                Logger.Error($"Unblock failed - access denied: {path} - {ex.Message}");
                return false;
            }
            catch (IOException ex)
            {
                error = $"IO error: {ex.Message}";
                Logger.Error($"Unblock failed - IO error: {path} - {ex.Message}");
                return false;
            }
            catch (Exception ex)
            {
                error = $"Unexpected error: {ex.Message}";
                Logger.Error($"Unblock failed - unexpected error: {path} - {ex.GetType().Name}: {ex.Message}");
                return false;
            }
        }

        public static bool Block(string path, out string? error, int zoneId = 3)
        {
            error = null;

            if (string.IsNullOrWhiteSpace(path))
            {
                error = "File path cannot be empty.";
                return false;
            }

            if (zoneId < 0 || zoneId > 4)
            {
                error = "Invalid zone ID. Must be 0-4.";
                Logger.Warn($"Block failed - invalid zone ID {zoneId}: {path}");
                return false;
            }

            try
            {
                if (!File.Exists(path))
                {
                    error = "File does not exist.";
                    Logger.Warn($"Block failed - file not found: {path}");
                    return false;
                }

                var zoneStream = ZoneStream(path);
                using (var sw = new StreamWriter(zoneStream, false))
                {
                    sw.WriteLine("[ZoneTransfer]");
                    sw.WriteLine($"ZoneId={zoneId}");
                    sw.WriteLine($"HostUrl=about:internet");
                }

                Logger.Info($"Successfully blocked (ZoneId={zoneId}): {path}");
                return true;
            }
            catch (UnauthorizedAccessException ex)
            {
                error = $"Access denied: {ex.Message}";
                Logger.Error($"Block failed - access denied: {path} - {ex.Message}");
                return false;
            }
            catch (IOException ex)
            {
                error = $"IO error: {ex.Message}";
                Logger.Error($"Block failed - IO error: {path} - {ex.Message}");
                return false;
            }
            catch (Exception ex)
            {
                error = $"Unexpected error: {ex.Message}";
                Logger.Error($"Block failed - unexpected error: {path} - {ex.GetType().Name}: {ex.Message}");
                return false;
            }
        }
    }
}
