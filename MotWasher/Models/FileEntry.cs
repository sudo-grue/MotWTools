using System.ComponentModel;
using System.Globalization;
using System.Runtime.CompilerServices;

namespace MotWasher.Models
{
    public class FileEntry : INotifyPropertyChanged
    {
        private bool _selected;
        private bool _hasMotw;
        private int? _currentZoneId;
        private int? _nextZoneId;

        public string FullPath { get; }
        public string Name { get; }
        public string Extension { get; }
        public long SizeBytes { get; }
        public DateTime ModifiedUtc { get; }

        public bool Selected
        {
            get => _selected;
            set { _selected = value; OnPropertyChanged(); }
        }

        public bool HasMotW
        {
            get => _hasMotw;
            set { _hasMotw = value; OnPropertyChanged(); OnPropertyChanged(nameof(CurrentZoneDisplay)); OnPropertyChanged(nameof(NextZoneDisplay)); }
        }

        public int? CurrentZoneId
        {
            get => _currentZoneId;
            set { _currentZoneId = value; OnPropertyChanged(); OnPropertyChanged(nameof(CurrentZoneDisplay)); OnPropertyChanged(nameof(NextZoneDisplay)); }
        }

        public int? NextZoneId
        {
            get => _nextZoneId;
            set { _nextZoneId = value; OnPropertyChanged(); OnPropertyChanged(nameof(NextZoneDisplay)); }
        }

        public string CurrentZoneDisplay => FormatZone(CurrentZoneId, true);
        public string NextZoneDisplay => FormatZone(NextZoneId, false);

        public string SizeDisplay => FormatBytes(SizeBytes);
        public string ModifiedLocal => ModifiedUtc.ToLocalTime().ToString("G", CultureInfo.CurrentCulture);

        public FileEntry(string fullPath, string name, string extension, long sizeBytes, DateTime modifiedUtc, bool hasMotw)
        {
            if (string.IsNullOrWhiteSpace(fullPath))
                throw new ArgumentException("File path cannot be null or empty.", nameof(fullPath));
            if (string.IsNullOrWhiteSpace(name))
                throw new ArgumentException("File name cannot be null or empty.", nameof(name));
            if (sizeBytes < 0)
                throw new ArgumentOutOfRangeException(nameof(sizeBytes), "File size cannot be negative.");

            FullPath = fullPath;
            Name = name;
            Extension = extension ?? string.Empty;
            SizeBytes = sizeBytes;
            ModifiedUtc = modifiedUtc;
            _hasMotw = hasMotw;
        }

        private static string FormatBytes(long bytes)
        {
            if (bytes == 0) return "0 B";
            if (bytes < 0) return "Invalid";

            string[] sizes = { "B", "KB", "MB", "GB", "TB" };
            double len = bytes;
            int order = 0;

            while (len >= 1024 && order < sizes.Length - 1)
            {
                order++;
                len /= 1024;
            }

            string format = order == 0 ? "0" : "0.##";
            return $"{len.ToString(format, CultureInfo.InvariantCulture)} {sizes[order]}";
        }

        private static string FormatZone(int? zoneId, bool isCurrent)
        {
            if (!zoneId.HasValue)
            {
                return isCurrent ? "No MotW" : "✓ Clean";
            }

            return zoneId.Value switch
            {
                0 => "0 - Local",
                1 => "1 - Intranet",
                2 => "2 - Trusted",
                3 => "3 - Internet",
                4 => "4 - Restricted",
                _ => $"Zone {zoneId.Value}"
            };
        }

        public override string ToString() => $"{Name} ({SizeDisplay}) - MotW: {HasMotW}";

        public event PropertyChangedEventHandler? PropertyChanged;
        private void OnPropertyChanged([CallerMemberName] string? prop = null)
            => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(prop));
    }
}
