using System.IO;

namespace MotWUnblocker.Services
{
    public static class MotWService
    {
        // Mark-of-the-Web lives in the NTFS Alternate Data Stream "Zone.Identifier"
        private static string ZoneStream(string path) => path + ":Zone.Identifier";

        public static bool HasMotW(string path)
        {
            try
            {
                return File.Exists(ZoneStream(path));
            }
            catch
            {
                return false; // safest default if we can't check
            }
        }

        public static bool Unblock(string path, out string? error)
        {
            error = null;
            try
            {
                var z = ZoneStream(path);
                if (File.Exists(z))
                {
                    File.Delete(z);
                }
                return true;
            }
            catch (Exception ex)
            {
                error = ex.Message;
                return false;
            }
        }

        public static bool Block(string path, out string? error, int zoneId = 3)
        {
            // ZoneId: 3 = Internet zone (classic MotW)
            error = null;
            try
            {
                // Ensure file exists
                if (!File.Exists(path))
                {
                    error = "File does not exist.";
                    return false;
                }

                var z = ZoneStream(path);
                using var sw = new StreamWriter(z, false);
                sw.WriteLine("[ZoneTransfer]");
                sw.WriteLine($"ZoneId={zoneId}");
                sw.Flush();
                return true;
            }
            catch (Exception ex)
            {
                error = ex.Message;
                return false;
            }
        }
    }
}
